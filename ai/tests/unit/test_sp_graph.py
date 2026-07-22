import pytest

from app.workflows.sp_graph import StateGraph, generate_reply


def test_sp_graph_dependency_is_optional():
    # The source tree remains importable before the optional worker dependency is installed.
    assert StateGraph is None or callable(StateGraph)


@pytest.mark.asyncio
async def test_sp_graph_node_collects_stream(monkeypatch):
    async def fake_stream(*args, **kwargs):
        yield "a"
        yield "b"

    monkeypatch.setattr("app.workflows.sp_graph.sp_reply_stream", fake_stream)
    result = await generate_reply({"case_context": "case", "history": [], "trace_id": "t"})
    assert result == {"reply": "ab"}
