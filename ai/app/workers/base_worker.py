"""Worker loop primitives. Process supervision is intentionally external (Docker/systemd)."""
from collections.abc import Awaitable, Callable
from typing import Any

from app.domain.enums import TaskStatus
from app.workers.task_models import TaskEnvelope
from app.workers.task_queue import TaskQueue


class TaskWorker:
    def __init__(self, queue: TaskQueue, task_type: str, handler: Callable[[dict[str, Any]], Awaitable[str | dict[str, Any] | None]]) -> None:
        self.queue = queue
        self.task_type = task_type
        self.handler = handler

    async def run_once(self) -> TaskEnvelope | None:
        task = await self.queue.claim(self.task_type)
        if task is None:
            return None
        try:
            outcome = await self.handler(task.payload)
            if isinstance(outcome, dict):
                task.result = outcome
            else:
                task.result_ref = outcome
            task.transition(TaskStatus.SUCCEEDED)
        except Exception as exc:  # noqa: BLE001
            retryable = task.attempts < task.max_attempts
            task.transition(
                TaskStatus.FAILED_RETRYABLE if retryable else TaskStatus.FAILED_FINAL,
                error_code=type(exc).__name__,
                error_message=str(exc)[:500],
            )
        if task.status is TaskStatus.FAILED_RETRYABLE:
            return await self.queue.retry(task)
        return await self.queue.update(task)
