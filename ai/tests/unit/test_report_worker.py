import pytest

from app.core.errors import BackendDependencyError
from app.workers.report_worker import handle_report


@pytest.mark.asyncio
async def test_report_worker_requires_backend_facts(monkeypatch):
    from app.services.backend_client import backend_client

    async def missing(session_id, trace_id="-"):
        return None

    monkeypatch.setattr(backend_client, "report_context", missing)
    with pytest.raises(BackendDependencyError):
        await handle_report({"sessionId": 1})


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
    result = await handle_report({"sessionId": 1})
    assert result["sessionId"] == 1
    assert result["title"] == "report"
