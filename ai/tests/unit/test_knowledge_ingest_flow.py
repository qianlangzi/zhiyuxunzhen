"""教材入库闭环回归测试：重试幂等键、回调携带 ingestionId、错误清洗。

覆盖本次整改的核心行为：
1. 重试/重新入库携带不同 attemptKey → 幂等键不同 → AI 真正创建新任务重跑（而非复用旧失败任务）；
2. worker 成功/失败回调都携带 ingestionId，后端据此丢弃旧任务迟到回调（防乱序覆盖）；
3. 回调错误信息截断 + 换行折叠，避免超长/多行异常污染后端 JSON 与页面展示。
"""
import pytest

from app.domain.enums import TaskType
from app.workers.task_models import TaskEnvelope


def _idem(textbook_id: int, object_key: str, attempt_key: str = "v1") -> str:
    """与 app/api/knowledge.py 的幂等键构造保持一致的纯函数副本"""
    return f"knowledge:{textbook_id}:{object_key}:{(attempt_key or 'v1').strip()[:64]}"


def test_retry_uses_new_idempotency_key():
    """不同 attemptKey → 不同幂等键 → 重试真正重跑；同一 attemptKey → 幂等"""
    base = _idem(7, "ebooks/internal.pdf", "a1b2")
    retry = _idem(7, "ebooks/internal.pdf", "c3d4")
    assert base != retry
    assert _idem(7, "ebooks/internal.pdf", "a1b2") == base


@pytest.mark.asyncio
async def test_knowledge_worker_callback_carries_ingestion_id(monkeypatch):
    """成功路径：回调携带 payload 中的 ingestionId"""
    from app.workers import knowledge_worker

    calls = []

    async def fake_callback(textbook_id, status, error=None, ingestion_id=None, trace_id="-"):
        calls.append({"textbookId": textbook_id, "status": status,
                      "error": error, "ingestionId": ingestion_id})
        return True

    monkeypatch.setattr(knowledge_worker.backend_client, "knowledge_callback", fake_callback)
    monkeypatch.setattr(knowledge_worker, "handle_knowledge",
                        lambda payload: _fake_handle(payload))

    async def _fake_handle(payload):
        return "knowledge:7:5"

    class FakeQueue:
        def __init__(self):
            self._task = TaskEnvelope(
                task_id="task-abc",
                idempotency_key="knowledge:7:ebooks/i.pdf:a1b2",
                task_type=TaskType.KNOWLEDGE_INGEST,
                payload={"textbookId": 7, "objectKey": "ebooks/i.pdf",
                         "ingestionId": "task-abc"},
            )

        async def claim(self, task_type):
            self._task.attempts += 1  # 与真实 TaskQueue.claim 一致：领取即计一次尝试
            return self._task

        async def update(self, task):
            return task

        async def retry(self, task):
            return task

    worker = knowledge_worker.create_knowledge_worker(FakeQueue())
    task = await worker.run_once()
    assert task.status.value == "SUCCEEDED"
    assert len(calls) == 1
    assert calls[0]["ingestionId"] == "task-abc"
    assert calls[0]["status"] == 2


@pytest.mark.asyncio
async def test_knowledge_worker_failure_callback_carries_ingestion_id(monkeypatch):
    """失败路径：回调携带 ingestionId 且 status=3"""
    from app.workers import knowledge_worker

    calls = []

    async def fake_callback(textbook_id, status, error=None, ingestion_id=None, trace_id="-"):
        calls.append({"textbookId": textbook_id, "status": status,
                      "error": error, "ingestionId": ingestion_id})
        return True

    monkeypatch.setattr(knowledge_worker.backend_client, "knowledge_callback", fake_callback)

    async def failing_handle(payload):
        raise RuntimeError("Milvus 不可用")

    monkeypatch.setattr(knowledge_worker, "handle_knowledge", failing_handle)

    class FakeQueue:
        def __init__(self):
            self._task = TaskEnvelope(
                task_id="task-def",
                idempotency_key="knowledge:7:ebooks/i.pdf:c3d4",
                task_type=TaskType.KNOWLEDGE_INGEST,
                max_attempts=1,
                payload={"textbookId": 7, "objectKey": "ebooks/i.pdf",
                         "ingestionId": "task-def"},
            )

        async def claim(self, task_type):
            self._task.attempts += 1  # 与真实 TaskQueue.claim 一致：领取即计一次尝试
            return self._task

        async def update(self, task):
            return task

        async def retry(self, task):
            return task

    worker = knowledge_worker.create_knowledge_worker(FakeQueue())
    task = await worker.run_once()
    assert task.status.value == "FAILED_FINAL"
    assert len(calls) == 1
    assert calls[0]["ingestionId"] == "task-def"
    assert calls[0]["status"] == 3
    assert "Milvus 不可用" in calls[0]["error"]


@pytest.mark.asyncio
async def test_callback_error_sanitized(monkeypatch):
    """错误信息截断 ≤500 且换行/制表符折叠，避免污染后端 JSON 与页面"""
    from app.services.backend_client import BackendClient

    captured = {}

    async def fake_post(self, path, body, trace_id="-"):
        captured["path"] = path
        captured["body"] = body
        return True

    monkeypatch.setattr(BackendClient, "_post", fake_post)
    client = BackendClient()
    long_err = ("a\nb\tc " * 300) + "\n" + "x" * 200
    await client.knowledge_callback(7, 3, error=long_err, ingestion_id="task-abc")
    assert captured["path"] == "/api/internal/knowledge/callback"
    assert captured["body"]["ingestionId"] == "task-abc"
    assert captured["body"]["status"] == 3
    assert len(captured["body"]["error"]) <= 500
    assert "\n" not in captured["body"]["error"]
    assert "\t" not in captured["body"]["error"]
