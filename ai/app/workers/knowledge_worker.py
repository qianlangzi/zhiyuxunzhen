"""教材对象解析、清洗打标、多模态 embedding 和 Milvus 入库 Worker。

生产链路（实验验证 100% Top-1 检索准确率）：
  PDF → MMORE 容器（图文分离：文本+图片提取）
      → cleaning_service.label_mmore_chunks（垃圾过滤+三级章节识别+元数据打标）
      → rag_service.embed_multimodal（DashScope Qwen3-VL-Embedding，文本+图片融合向量）
      → milvus_service.upsert（含 subject/part/section/chapter/page 元数据）

降级链路（MMORE 不可用时）：
  PDF → cleaning_service.clean_and_label_bytes（PyMuPDF 文本+图片提取+清洗打标）
      → rag_service.embed_multimodal
      → milvus_service.upsert
"""
import json
from typing import Any

import httpx

from app.adapters.object_storage import object_storage
from app.core.config import settings
from app.core.errors import OutputSchemaInvalidError
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.services.cleaning_service import clean_and_label_bytes, label_mmore_chunks, CleanChunk
from app.services.milvus_service import milvus_service
from app.services.rag_service import rag_service
from app.workers.base_worker import TaskWorker
from app.workers.task_queue import TaskQueue

logger = get_logger(__name__)


async def _call_mmore(pdf_content: bytes, filename: str, trace_id: str) -> list[dict] | None:
    """调用 MMORE 服务处理 PDF，返回 chunks [{text, page, images}]。

    失败时返回 None，调用方降级到 PyMuPDF 方案。
    """
    mmore_url = settings.mmore_url
    try:
        async with httpx.AsyncClient(timeout=300.0) as client:
            resp = await client.post(
                f"{mmore_url}/process",
                files={"file": (filename, pdf_content, "application/pdf")},
            )
            resp.raise_for_status()
            data = resp.json()
            chunks = data.get("chunks", [])
            log_event(logger, INFO, "mmore_processed",
                      trace_id=trace_id, chunks=len(chunks),
                      filename=filename)
            return chunks
    except Exception as e:
        log_event(logger, WARNING, "mmore_call_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e),
                  fallback="pymupdf")
        return None


async def handle_knowledge(payload: dict[str, Any]) -> str | None:
    object_key = str(payload.get("objectKey", "")).strip()
    textbook_id = int(payload.get("textbookId", 0))
    subject = str(payload.get("subject", "")).strip()
    book_name = str(payload.get("bookName", "")).strip()
    trace_id = payload.get("traceId", "-")

    if not object_key or textbook_id <= 0:
        raise OutputSchemaInvalidError("教材任务缺少有效的 textbookId/objectKey")

    # 1. 下载 PDF
    content = await object_storage.read(object_key)

    # 2. PDF 处理（优先 MMORE 图文分离，降级 PyMuPDF）
    mmore_chunks = await _call_mmore(content, object_key, trace_id)

    if mmore_chunks is not None:
        # MMORE 路径：图文分离 + 清洗打标
        chunks = label_mmore_chunks(
            content, mmore_chunks, subject=subject, book_name=book_name, trace_id=trace_id,
        )
        pipeline = "mmore"
    else:
        # 降级路径：PyMuPDF 文本+图片提取 + 清洗打标
        chunks = clean_and_label_bytes(
            content, subject=subject, book_name=book_name, trace_id=trace_id,
            extract_images=True,
        )
        pipeline = "pymupdf"

    if not chunks:
        raise OutputSchemaInvalidError("教材没有可提取的文本（清洗后为空）")

    image_count = sum(1 for c in chunks if c.image_path)
    log_event(logger, INFO, "knowledge_cleaned",
              trace_id=trace_id, textbook_id=textbook_id,
              total_chunks=len(chunks), with_images=image_count,
              subject=subject or "auto", pipeline=pipeline)

    # 3. 多模态 embedding（DashScope Qwen3-VL-Embedding）
    #    有图片的 chunk 用 text+image 融合向量，无图片的用纯文本
    #    DashScope 不支持批量，逐条调用
    records = []
    for index, chunk in enumerate(chunks):
        try:
            vector = await rag_service.embed_multimodal(
                chunk.text, image_path=chunk.image_path, trace_id=trace_id,
            )
        except Exception as e:
            log_event(logger, WARNING, "knowledge_embed_fail",
                      trace_id=trace_id, chunk_index=index, error=str(e))
            continue

        records.append({
            "id": f"tb{textbook_id}_c{index}",
            "vector": vector,
            "book_name": chunk.book,
            "edition": payload.get("edition") or "",
            "chapter": chunk.chapter,
            "page_number": chunk.page,
            "chunk_text": chunk.text[:4000],
            "subject": chunk.subject,
            "part": chunk.part,
            "section": chunk.section,
        })

    if not records:
        raise OutputSchemaInvalidError(
            f"教材 embedding 全部失败（{len(chunks)} chunks, 0 成功）"
        )

    # 4. 入库 Milvus
    inserted = await milvus_service.upsert(records, trace_id=trace_id)
    if inserted != len(records):
        raise RuntimeError(f"Milvus 仅写入 {inserted}/{len(records)} 个向量")

    log_event(logger, INFO, "knowledge_ingested",
              trace_id=trace_id, textbook_id=textbook_id,
              inserted=inserted, subject=subject or "auto",
              pipeline=pipeline, with_images=image_count)
    return f"knowledge:{textbook_id}:{inserted}"


def create_knowledge_worker(queue: TaskQueue) -> TaskWorker:
    return TaskWorker(queue, "knowledge_ingest", handle_knowledge)
