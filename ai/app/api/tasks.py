"""Internal asynchronous task submission and status APIs."""
from typing import Any

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from app.core.errors import TaskNotFoundError
from app.core.security import require_internal_token
from app.domain.enums import TaskType
from app.models.common import R
from app.workers.task_models import TaskEnvelope
from app.workers.task_queue import TaskQueue

router = APIRouter()


class TaskSubmitRequest(BaseModel):
    taskType: TaskType
    idempotencyKey: str = Field(min_length=1, max_length=200)
    payload: dict[str, Any]
    maxAttempts: int = Field(default=3, ge=1, le=10)


@router.post("/v1/ai/tasks", response_model=R)
async def submit_task(req: TaskSubmitRequest, request: Request, _token: None = Depends(require_internal_token)):
    queue = TaskQueue(getattr(request.app.state, "redis_client", None))
    task = await queue.enqueue(TaskEnvelope(
        idempotency_key=req.idempotencyKey,
        task_type=req.taskType,
        payload=req.payload,
        max_attempts=req.maxAttempts,
    ))
    return R(data=task.model_dump(mode="json"))


@router.get("/v1/ai/tasks/{task_id}", response_model=R)
async def get_task(task_id: str, request: Request, _token: None = Depends(require_internal_token)):
    task = await TaskQueue(getattr(request.app.state, "redis_client", None)).get(task_id)
    if task is None:
        raise TaskNotFoundError(task_id)
    return R(data=task.model_dump(mode="json"))
