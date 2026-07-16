"""教材向量化嵌入（PRD 9.3）

POST /embed/textbook
1. 下载 PDF
2. 解析切块
3. 批量 embedding
4. 写入 Milvus（带内存 fallback）
"""
import uuid

from fastapi import APIRouter, Depends

from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.embed import EmbedTextbookRequest, EmbedTextbookResult
from app.services.milvus_service import milvus_service
from app.services.pdf_service import fetch_pdf, parse_pdf
from app.services.rag_service import rag_service

logger = get_logger(__name__)
router = APIRouter()


@router.post("/embed/textbook", response_model=R)
async def embed_textbook(
    req: EmbedTextbookRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        # 1. 下载 PDF
        try:
            content = fetch_pdf(req.fileUrl, trace_id=trace_id)
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "embed_fetch_failed",
                      trace_id=trace_id, url=req.fileUrl, error=str(e))
            return R(
                code=400,
                message=f"教材 PDF 下载失败：{e}",
                data=EmbedTextbookResult(
                    textbookId=req.textbookId,
                    chunkCount=0, vectorCount=0,
                    status="failed", message=str(e),
                ).model_dump(),
            )

        # 2. 解析切块
        chunks = parse_pdf(content, trace_id=trace_id)
        if not chunks:
            return R(
                code=400,
                message="PDF 解析后未得到任何文本",
                data=EmbedTextbookResult(
                    textbookId=req.textbookId,
                    chunkCount=0, vectorCount=0,
                    status="failed", message="PDF 内容为空或无法解析",
                ).model_dump(),
            )

        # 3. 批量 embedding
        texts = [c.text for c in chunks]
        vectors = await rag_service.embed_batch(texts, trace_id=trace_id)

        # 4. 写入 Milvus（带内存 fallback）
        records = []
        for idx, (chunk, vec) in enumerate(zip(chunks, vectors, strict=True)):
            records.append({
                "id": f"tb{req.textbookId}_c{idx}",
                "vector": vec,
                "book_name": f"textbook-{req.textbookId}",
                "edition": "",
                "chapter": chunk.chapter,
                "page_number": chunk.page_number,
                "chunk_text": chunk.text,
            })
        inserted = await milvus_service.upsert(records, trace_id=trace_id)

        status = "success" if inserted == len(records) else "partial"
        result = EmbedTextbookResult(
            textbookId=req.textbookId,
            chunkCount=len(chunks),
            vectorCount=inserted,
            status=status,
        )
        log_event(logger, INFO, "embed_done",
                  trace_id=trace_id, textbook_id=req.textbookId,
                  chunks=len(chunks), inserted=inserted)
        return R(data=result.model_dump())
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "embed_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"向量化失败：{e}", data=None)
    finally:
        reset_context()
