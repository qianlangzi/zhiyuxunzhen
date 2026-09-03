import pytest

from app.domain.enums import TaskStatus, TaskType
from app.workers.base_worker import TaskWorker
from app.workers.task_models import TaskEnvelope


class FakeQueue:
    def __init__(self, task):
        self.task = task

    async def claim(self, task_type):
        return self.task

    async def update(self, task):
        return task

    async def retry(self, task):
        return task


@pytest.mark.asyncio
async def test_worker_marks_success_and_result_ref():
    task = TaskEnvelope(idempotency_key="x", task_type=TaskType.REVIEW, payload={})
    worker = TaskWorker(FakeQueue(task), "review", lambda payload: _result())
    result = await worker.run_once()
    assert result.status is TaskStatus.SUCCEEDED
    assert result.result_ref == "done"


async def _result():
    return "done"


@pytest.mark.asyncio
async def test_worker_marks_retryable_failure():
    task = TaskEnvelope(idempotency_key="y", task_type=TaskType.REVIEW, payload={}, max_attempts=2)

    async def fail(payload):
        raise RuntimeError("temporary")

    result = await TaskWorker(FakeQueue(task), "review", fail).run_once()
    assert result.status is TaskStatus.FAILED_RETRYABLE
    assert result.error_code == "RuntimeError"
