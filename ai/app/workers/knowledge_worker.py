"""教材对象解析、向量化和 Milvus 入库 Worker。"""
from typing import Any

from app.adapters.object_storage import object_storage
from app.core.errors import OutputSchemaInvalidError
from app.services.milvus_service import milvus_service
from app.services.pdf_service import parse_pdf
from app.services.rag_service import rag_service
from app.workers.base_worker import TaskWorker
from app.workers.task_queue import TaskQueue


async def handle_knowledge(payload: dict[str, Any]) -> str | None:
    object_key = str(payload.get("objectKey", "")).strip()
    textbook_id = int(payload.get("textbookId", 0))
    if not object_key or textbook_id <= 0:
        raise OutputSchemaInvalidError("教材任务缺少有效的 textbookId/objectKey")
    content = await object_storage.read(object_key)
    chunks = parse_pdf(content, trace_id=payload.get("traceId", "-"))
    if not chunks:
        raise OutputSchemaInvalidError("教材没有可提取的文本")
    vectors = await rag_service.embed_batch(
        [chunk.text for chunk in chunks], trace_id=payload.get("traceId", "-")
    )
    records = [
        {
            "id": f"tb{textbook_id}_c{index}",
            "vector": vector,
            "book_name": payload.get("bookName") or f"textbook-{textbook_id}",
            "edition": payload.get("edition") or "",
            "chapter": chunk.chapter,
            "page_number": chunk.page_number,
            "chunk_text": chunk.text,
        }
        for index, (chunk, vector) in enumerate(zip(chunks, vectors, strict=True))
    ]
    inserted = await milvus_service.upsert(records, trace_id=payload.get("traceId", "-"))
    if inserted != len(records):
        raise RuntimeError(f"Milvus 仅写入 {inserted}/{len(records)} 个向量")
    return f"knowledge:{textbook_id}:{inserted}"


def create_knowledge_worker(queue: TaskQueue) -> TaskWorker:
    return TaskWorker(queue, "knowledge_ingest", handle_knowledge)
