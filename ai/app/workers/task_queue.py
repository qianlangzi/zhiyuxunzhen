"""Redis-backed task queue primitives; no business workflow lives here."""
import json
from datetime import datetime, timezone
from typing import Any

from app.core.errors import BackendDependencyError
from app.domain.enums import TaskStatus
from app.workers.task_models import TaskEnvelope


class TaskQueue:
    def __init__(self, redis: Any, *, namespace: str = "zhiyu:ai:task") -> None:
        self.redis = redis
        self.namespace = namespace

    def _task_key(self, task_id: str) -> str:
        return f"{self.namespace}:item:{task_id}"

    def _idem_key(self, key: str) -> str:
        return f"{self.namespace}:idem:{key}"

    def _queue_key(self, task_type: str) -> str:
        return f"{self.namespace}:queue:{task_type}"

    async def enqueue(self, task: TaskEnvelope) -> TaskEnvelope:
        if self.redis is None:
            raise BackendDependencyError("Redis task queue 未配置")
        reserved = await self.redis.set(
            self._idem_key(task.idempotency_key), task.task_id, ex=86400, nx=True
        )
        if not reserved:
            existing = await self.redis.get(self._idem_key(task.idempotency_key))
            stored = await self.get(existing) if existing else None
            if stored:
                return stored
        payload = task.model_dump(mode="json")
        created = await self.redis.set(self._task_key(task.task_id), json.dumps(payload, ensure_ascii=False), nx=True)
        if not created:
            stored = await self.get(task.task_id)
            if stored:
                return stored
        await self.redis.lpush(self._queue_key(task.task_type.value), task.task_id)
        return task

    async def get(self, task_id: str) -> TaskEnvelope | None:
        if self.redis is None:
            raise BackendDependencyError("Redis task queue 未配置")
        raw = await self.redis.get(self._task_key(task_id))
        return TaskEnvelope.model_validate_json(raw) if raw else None

    async def update(self, task: TaskEnvelope) -> TaskEnvelope:
        if self.redis is None:
            raise BackendDependencyError("Redis task queue 未配置")
        task.updated_at = datetime.now(timezone.utc)
        await self.redis.set(self._task_key(task.task_id), task.model_dump_json())
        return task

    async def retry(self, task: TaskEnvelope) -> TaskEnvelope:
        await self.update(task)
        await self.redis.lpush(self._queue_key(task.task_type.value), task.task_id)
        return task

    async def claim(self, task_type: str) -> TaskEnvelope | None:
        if self.redis is None:
            raise BackendDependencyError("Redis task queue 未配置")
        item = await self.redis.rpop(self._queue_key(task_type))
        if not item:
            return None
        task = await self.get(item)
        if task is None or task.status not in (TaskStatus.PENDING, TaskStatus.FAILED_RETRYABLE):
            return None
        task.attempts += 1
        task.transition(TaskStatus.RUNNING)
        return await self.update(task)
