"""教材向量化嵌入（PRD 9.3）

POST /embed/textbook
1. 下载 PDF（带 SSRF 安全校验）
2. 解析切块
3. 批量 embedding
4. 写入 Milvus（带内存 fallback）

chunk_id 使用 textbookId + 内容哈希生成，重新入库能正确去重。
"""
import hashlib
import ipaddress
import uuid
from urllib.parse import urlparse

from fastapi import APIRouter, Depends

from app.core.logging import ensure_trace_id, get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.embed import EmbedTextbookRequest, EmbedTextbookResult
from app.services.milvus_service import milvus_service
from app.services.pdf_service import fetch_pdf, parse_pdf
from app.services.rag_service import rag_service

logger = get_logger(__name__)
router = APIRouter()


def _is_safe_url(url: str) -> tuple[bool, str]:
    """检查 URL 是否安全（防止 SSRF）

    - 必须是 http 或 https 协议
    - 不能指向 localhost / 127.0.0.0/8 / 内网 IP / 链路本地地址
    """
    try:
        parsed = urlparse(url)
    except Exception:
        return False, "URL 格式不合法"

    if parsed.scheme not in ("http", "https"):
        return False, f"不支持的协议: {parsed.scheme}，仅允许 http/https"

    hostname = parsed.hostname
    if not hostname:
        return False, "URL 缺少主机名"

    # 禁止 localhost
    if hostname in ("localhost", "::1", "0.0.0.0"):
        return False, "禁止访问本地地址"

    # 检查是否是内网 IP
    try:
        ip = ipaddress.ip_address(hostname)
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
            return False, f"禁止访问内网地址: {hostname}"
    except ValueError:
        # 不是 IP 地址（是域名），允许通过
        pass

    return True, ""


@router.post("/embed/textbook", response_model=R)
async def embed_textbook(
    req: EmbedTextbookRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # 0. SSRF 安全校验
        safe, reason = _is_safe_url(req.fileUrl)
        if not safe:
            log_event(logger, WARNING, "embed_url_blocked",
                      trace_id=trace_id, url=req.fileUrl, reason=reason)
            return R(
                code=400,
                message=f"URL 安全校验失败：{reason}",
                data=EmbedTextbookResult(
                    textbookId=req.textbookId,
                    chunkCount=0, vectorCount=0,
                    status="failed", message=reason,
                ).model_dump(),
            )

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
        # chunk_id 使用 textbookId + 内容哈希，重新入库能正确去重
        records = []
        for chunk, vec in zip(chunks, vectors, strict=True):
            source_hash = hashlib.md5(
                f"{req.textbookId}:{chunk.text}".encode()
            ).hexdigest()[:12]
            records.append({
                "id": f"tb{req.textbookId}_{source_hash}",
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
