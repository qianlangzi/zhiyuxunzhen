"""受控教材对象的异步入库入口。"""
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from app.core.security import require_internal_token
from app.domain.enums import TaskType
from app.models.common import R
from app.workers.task_models import TaskEnvelope
from app.workers.task_queue import TaskQueue

router = APIRouter()


class KnowledgeIngestRequest(BaseModel):
    textbookId: int = Field(gt=0)
    objectKey: str = Field(min_length=1, max_length=500)
    bookName: str | None = Field(default=None, max_length=200)
    edition: str | None = Field(default=None, max_length=50)


@router.post("/knowledge/ingest", response_model=R)
async def ingest_knowledge(
    req: KnowledgeIngestRequest,
    request: Request,
    _token: None = Depends(require_internal_token),
):
    task = await TaskQueue(getattr(request.app.state, "redis_client", None)).enqueue(
        TaskEnvelope(
            idempotency_key=f"knowledge:{req.textbookId}:{req.objectKey}",
            task_type=TaskType.KNOWLEDGE_INGEST,
            payload=req.model_dump(),
        )
    )
    return R(data={"ingestionId": task.task_id, "status": task.status.value})
