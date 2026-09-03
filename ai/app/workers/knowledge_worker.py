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
import os
from typing import Any

import httpx

from app.adapters.object_storage import object_storage
from app.core.config import settings
from app.core.errors import OutputSchemaInvalidError
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.services.backend_client import backend_client
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
        async with httpx.AsyncClient(timeout=600.0) as client:
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
    subject = str(payload.get("subject", "") or "").strip()
    book_name = str(payload.get("bookName", "") or "").strip()
    # 可选：指定目标 collection（默认 settings.milvus_collection 生产集合）。
    # payload 中未传的字段会被序列化为 null（get 返回 None），不能直接 str() 包裹，
    # 否则会得到字符串 "None" 并被当作真实 collection 名去 describe，导致 upsert 必失败。
    raw_collection = payload.get("collectionName")
    collection = raw_collection.strip() if isinstance(raw_collection, str) and raw_collection.strip() else None
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

    # 3. 多模态 embedding（DashScope Qwen3-VL-Embedding，并发池加速）
    #    有图片的 chunk 用 text+image 融合向量，无图片的用纯文本
    vectors = await rag_service.embed_multimodal_batch(
        [(c.text, c.image_path) for c in chunks], trace_id=trace_id,
    )

    # 4. 图片持久化到对象存储 + 登记 chunk_id→image_key 映射
    #    （原临时目录图片会被清理，不持久化则生成侧多模态无法回查原图）
    from app.services.image_index_service import image_index_service

    records = []
    persisted_images = 0
    embed_failed = 0
    for index, chunk in enumerate(chunks):
        vector = vectors[index]
        if vector is None:
            embed_failed += 1
            log_event(logger, WARNING, "knowledge_embed_fail",
                      trace_id=trace_id, chunk_index=index)
            continue

        # 图片临时文件 → 对象存储
        if chunk.image_path and os.path.exists(chunk.image_path):
            with open(chunk.image_path, "rb") as f:
                img_bytes = f.read()
            if img_bytes:
                ext = os.path.splitext(chunk.image_path)[1].lower().lstrip(".") or "png"
                image_key = await image_index_service.register(
                    f"tb{textbook_id}_c{index}", img_bytes, ext,
                    meta={"book": chunk.book, "page": chunk.page},
                )
                if image_key:
                    persisted_images += 1

        records.append({
            "id": f"tb{textbook_id}_c{index}",
            "vector": vector,
            # 长度截断保护：超长（乱码/异常解析）会导致 Milvus upsert 整批失败
            "book_name": (chunk.book or "")[:200],
            "edition": (payload.get("edition") or "")[:50],
            "chapter": (chunk.chapter or "")[:200],
            "page_number": chunk.page,
            "chunk_text": chunk.text[:4000],
            "subject": (chunk.subject or "")[:128],
            "part": (chunk.part or "")[:256],
            "section": (chunk.section or "")[:256],
        })

    if not records:
        raise OutputSchemaInvalidError(
            f"教材 embedding 全部失败（{len(chunks)} chunks, 0 成功）"
        )
    if embed_failed:
        log_event(logger, WARNING, "knowledge_embed_partial_fail",
                  trace_id=trace_id, failed=embed_failed, total=len(chunks))

    # 5. 入库 Milvus（按目标 collection schema 自动映射字段名）
    inserted = await milvus_service.upsert(records, trace_id=trace_id, collection_name=collection)
    if inserted != len(records):
        raise RuntimeError(f"Milvus 仅写入 {inserted}/{len(records)} 个向量")

    # 6. BM25 增量更新（全量视图）+ 分科视图失效（下次检索自动重建带回新数据）
    col_name = collection or settings.milvus_collection
    try:
        from app.services.hybrid_retrieval import bm25_append, bm25_invalidate
        bm25_append(
            col_name,
            None,
            [{"id": r["id"], "chunk_text": r["chunk_text"], "book_name": r["book_name"],
              "chapter": r["chapter"], "page_number": r["page_number"],
              "subject": r["subject"], "part": r["part"], "section": r["section"]}
             for r in records],
        )
        # 分科视图无法增量（新 chunk 的 subject 归属由重建时过滤决定），直接失效
        bm25_invalidate(col_name, subject)
        bm25_invalidate(col_name, None)  # 保险：bm25_append 无内存缓存时已清磁盘，此处幂等
    except Exception as e:  # noqa: BLE001 - BM25 增量失败不影响入库结果
        log_event(logger, WARNING, "bm25_append_failed",
                  trace_id=trace_id, error=type(e).__name__)

    log_event(logger, INFO, "knowledge_ingested",
              trace_id=trace_id, textbook_id=textbook_id,
              inserted=inserted, subject=subject or "auto",
              pipeline=pipeline, with_images=image_count,
              images_persisted=persisted_images)
    return f"knowledge:{textbook_id}:{inserted}"


def create_knowledge_worker(queue: TaskQueue) -> TaskWorker:
    """构造知识入库 worker，并在成功/失败时把入库状态回调给业务中台（2 成功 / 3 失败）。

    回调携带 ingestionId（payload 内嵌的任务 ID），业务中台据此丢弃旧任务的迟到回调，
    防止「旧任务失败回调覆盖新任务成功状态」的乱序污染。
    """
    async def handle_with_callback(payload: dict[str, Any]) -> str | None:
        textbook_id = int(payload.get("textbookId", 0))
        ingestion_id = payload.get("ingestionId")
        trace_id = payload.get("traceId", "-")
        try:
            outcome = await handle_knowledge(payload)
            await backend_client.knowledge_callback(
                textbook_id, 2, ingestion_id=ingestion_id, trace_id=trace_id,
            )
            return outcome
        except Exception as exc:  # noqa: BLE001 - 失败也需回调中台标记入库失败，再交由 worker 重试
            await backend_client.knowledge_callback(
                textbook_id, 3, error=str(exc), ingestion_id=ingestion_id, trace_id=trace_id,
            )
            raise

    return TaskWorker(queue, "knowledge_ingest", handle_with_callback)
