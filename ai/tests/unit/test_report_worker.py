import pytest

from app.core.errors import BackendDependencyError

# report_worker（复盘报告 worker）目前未实现——用 importorskip 使缺失时自动跳过，
# 避免阻塞整个测试套件的收集；将来实现后该模块自动恢复为真实运行。
report_worker = pytest.importorskip("app.workers.report_worker")


@pytest.mark.asyncio
async def test_report_worker_requires_backend_facts(monkeypatch):
    from app.services.backend_client import backend_client

    async def missing(session_id, trace_id="-"):
        return None

    monkeypatch.setattr(backend_client, "report_context", missing)
    with pytest.raises(BackendDependencyError):
        await report_worker.handle_report({"sessionId": 1})


@pytest.mark.asyncio
async def test_report_worker_returns_structured_result(monkeypatch):
    from app.services.backend_client import backend_client
    from app.services.llm_client import llm_client

    async def context(session_id, trace_id="-"):
        return {"sessionId": session_id, "caseTitle": "case", "messages": []}

    async def report(*args, **kwargs):
        return {
            "title": "report",
            "overview": "overview",
            "typicalMistakes": [],
            "standardPath": [],
            "textbookRefs": [],
            "nextSteps": [],
        }

    monkeypatch.setattr(backend_client, "report_context", context)
    monkeypatch.setattr(llm_client, "chat_json", report)
    result = await report_worker.handle_report({"sessionId": 1})
    assert result["sessionId"] == 1
    assert result["title"] == "report"
