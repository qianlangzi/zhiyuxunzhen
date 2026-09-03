"""工具调用（function calling）单元测试。

验证：
1. 工具注册表包含 search_textbook 及正确 schema
2. resolve_tools 会执行模型返回的 tool_calls 并把结果回填，再继续到最终文本
3. 未配置 LLM 时 resolve_tools 降级为返回原 messages（不阻断）
"""
import json
import sys
from types import SimpleNamespace

import pytest

sys.path.insert(0, ".")

from app.agents.toolkit import TOOLKIT, SearchTextbookTool, toolkit_list
from app.services.llm_client import llm_client
from app.services.rag_service import rag_service


def _tool_call_msg() -> SimpleNamespace:
    tc = SimpleNamespace(
        id="call_1",
        function=SimpleNamespace(
            name="search_textbook", arguments=json.dumps({"query": "胸痛"})
        ),
    )
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=None, tool_calls=[tc]))])


def _text_msg() -> SimpleNamespace:
    return SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content="基于教材，胸痛需考虑心梗风险。", tool_calls=None))]
    )


def _build_fake_client(responses):
    class _Completions:
        def __init__(self, rs):
            self._rs = rs
            self.calls = 0

        async def create(self, **kwargs):
            resp = self._rs[self.calls]
            self.calls += 1
            return resp

    class _Chat:
        def __init__(self, completions):
            self.completions = completions

    class _Client:
        def __init__(self, completions):
            self.chat = _Chat(completions)

    return _Client(_Completions(responses))


def test_toolkit_registers_search_textbook():
    assert "search_textbook" in TOOLKIT
    tool = TOOLKIT["search_textbook"]
    assert isinstance(tool, SearchTextbookTool)
    schema = tool.schema()
    assert schema["type"] == "function"
    assert schema["function"]["name"] == "search_textbook"
    assert "query" in schema["function"]["parameters"]["properties"]


@pytest.mark.asyncio
async def test_resolve_tools_executes_and_backfills(monkeypatch):
    fake = _build_fake_client([_tool_call_msg(), _text_msg()])
    monkeypatch.setattr(llm_client, "_client", fake)

    async def fake_search(query, top_k=5, trace_id="-", rewrite=False, history=None):
        return [SimpleNamespace(model_dump=lambda: {"book_name": "《内科学》", "chapter": "第3章", "chunk_text": "胸痛要点"})]

    monkeypatch.setattr(rag_service, "search", fake_search)

    messages = [{"role": "user", "content": "胸痛应该考虑什么？"}]
    result = await llm_client.resolve_tools(messages, toolkit_list(), trace_id="t")

    # 工具被调用了一次
    assert fake.chat.completions.calls == 2  # noqa: PLR2004
    roles = [m["role"] for m in result]
    assert "assistant" in roles and "tool" in roles
    # tool 消息内容来自工具执行结果
    tool_msgs = [m for m in result if m["role"] == "tool"]
    parsed = json.loads(tool_msgs[0]["content"])
    assert parsed[0]["book_name"] == "《内科学》"


@pytest.mark.asyncio
async def test_resolve_tools_degrades_when_llm_unavailable(monkeypatch):
    monkeypatch.setattr(llm_client, "_client", None)
    messages = [{"role": "user", "content": "test"}]
    result = await llm_client.resolve_tools(messages, toolkit_list(), trace_id="t")
    assert result == messages


@pytest.mark.asyncio
async def test_search_textbook_tool_returns_message_when_no_result(monkeypatch):
    async def fake_search(query, top_k=5, trace_id="-", rewrite=False, history=None):
        return []

    monkeypatch.setattr(rag_service, "search", fake_search)
    tool = TOOLKIT["search_textbook"]
    out = await tool.run({"query": "不存在的内容"}, trace_id="t")
    assert "未检索到" in out