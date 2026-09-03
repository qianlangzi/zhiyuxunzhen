"""异步任务的稳定数据契约。"""
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from pydantic import BaseModel, Field

from app.domain.enums import TaskStatus, TaskType


class TaskEnvelope(BaseModel):
    task_id: str = Field(default_factory=lambda: str(uuid4()))
    idempotency_key: str = Field(min_length=1)
    task_type: TaskType
    payload: dict[str, Any]
    status: TaskStatus = TaskStatus.PENDING
    attempts: int = 0
    max_attempts: int = Field(default=3, ge=1, le=10)
    error_code: str | None = None
    error_message: str | None = None
    result_ref: str | None = None
    result: dict[str, Any] | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    def transition(self, status: TaskStatus, *, error_code: str | None = None, error_message: str | None = None) -> "TaskEnvelope":
        self.status = status
        self.error_code = error_code
        self.error_message = error_message
        self.updated_at = datetime.now(timezone.utc)
        return self
