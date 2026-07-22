import pytest

from app.agents.evaluator_agent import evaluate
from app.agents.reviewer_agent import review
from app.core.errors import OutputSchemaInvalidError


@pytest.mark.asyncio
async def test_reviewer_rejects_missing_score(monkeypatch):
    from app.services.llm_client import llm_client

    async def invalid(*args, **kwargs):
        return {"unexpected": True}

    monkeypatch.setattr(llm_client, "chat_json", invalid)
    with pytest.raises(OutputSchemaInvalidError):
        await review("record", trace_id="test")


@pytest.mark.asyncio
async def test_evaluator_rejects_partial_scores(monkeypatch):
    from app.services.llm_client import llm_client

    async def invalid(*args, **kwargs):
        return {"scores": {"history": 20}}

    monkeypatch.setattr(llm_client, "chat_json", invalid)
    with pytest.raises(OutputSchemaInvalidError):
        await evaluate("case", [], trace_id="test")
