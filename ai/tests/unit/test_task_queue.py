import pytest

from app.domain.enums import TaskStatus, TaskType
from app.workers.task_models import TaskEnvelope


def test_task_envelope_has_auditable_defaults():
    task = TaskEnvelope(idempotency_key="review:1", task_type=TaskType.REVIEW, payload={"instanceId": 1})
    assert task.status is TaskStatus.PENDING
    assert task.attempts == 0
    assert task.max_attempts == 3
    assert task.task_id


@pytest.mark.asyncio
async def test_queue_requires_redis():
    from app.workers.task_queue import TaskQueue
    task = TaskEnvelope(idempotency_key="review:2", task_type=TaskType.REVIEW, payload={})
    with pytest.raises(Exception, match="Redis"):
        await TaskQueue(None).enqueue(task)
