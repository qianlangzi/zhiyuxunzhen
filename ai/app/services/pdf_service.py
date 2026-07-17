"""PDF 解析与切块（PRD 7.3.1）

使用 pypdf 解析 PDF，按字符长度滑动切块（默认 1000 字符，重叠 200 字符）。
保留页码信息，便于 RAG 溯源。
"""
import io
from dataclasses import dataclass

import httpx
from pypdf import PdfReader

from app.core.logging import get_logger, log_event
from logging import INFO, WARNING

logger = get_logger(__name__)

CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200


@dataclass
class TextChunk:
    """教材切块"""

    text: str
    page_number: int
    chapter: str = "未分类"


def fetch_pdf(file_url: str, trace_id: str = "-") -> bytes:
    """从 URL 下载 PDF 内容"""
    try:
        with httpx.Client(timeout=60.0, follow_redirects=True) as c:
            resp = c.get(file_url)
            resp.raise_for_status()
            return resp.content
    except httpx.HTTPError as e:
        log_event(logger, WARNING, "pdf_fetch_error",
                  trace_id=trace_id, url=file_url, error=type(e).__name__)
        raise


def parse_pdf(content: bytes, trace_id: str = "-") -> list[TextChunk]:
    """解析 PDF 为 TextChunk 列表"""
    reader = PdfReader(io.BytesIO(content))
    chunks: list[TextChunk] = []
    for page_idx, page in enumerate(reader.pages, start=1):
        text = (page.extract_text() or "").strip()
        if not text:
            continue
        # 按字符长度切块
        start = 0
        while start < len(text):
            end = start + CHUNK_SIZE
            piece = text[start:end].strip()
            if piece:
                chunks.append(TextChunk(text=piece, page_number=page_idx))
            start = end - CHUNK_OVERLAP
            if start >= len(text):
                break
    log_event(logger, INFO, "pdf_parsed",
              trace_id=trace_id, pages=len(reader.pages), chunks=len(chunks))
    return chunks
