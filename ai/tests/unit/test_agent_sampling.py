"""Agent 采样上下文（S1 热配参数打通）的单元测试。

验证：agent_gateway 写入的 AgentSpec 采样参数（temperature/max_tokens/model）
会作为 llm_client 的默认值回退生效；未设置时回退全局 settings 默认。
"""
import types

import pytest

from app.core.logging import get_agent_sampling, set_agent_sampling
from app.services import llm_client as llm_client_mod
from app.services.llm_client import llm_client


class _FakeChoice:
    content = "ok"


class _FakeMessage:
    choices = [types.SimpleNamespace(message=_FakeChoice())]
    usage = types.SimpleNamespace(prompt_tokens=3, completion_tokens=2, total_tokens=5)


class _FakeCompletions:
    def __init__(self) -> None:
        self.captured: dict = {}

    async def create(self, **kwargs) -> _FakeMessage:
        self.captured.update(kwargs)
        return _FakeMessage()


@pytest.fixture(autouse=True)
def _clean_agent_context():
    set_agent_sampling(None, None, None)
    yield
    set_agent_sampling(None, None, None)


async def _run_chat(monkeypatch, captured):
    fake = _FakeCompletions()
    captured["call"] = fake
    fake_client = types.SimpleNamespace(
        chat=types.SimpleNamespace(completions=fake)
    )
    monkeypatch.setattr(llm_client, "_client", fake_client)
    # 旁路上报不依赖网络，置空避免真实回调
    async def _noop_report(*a, **k):
        return None

    monkeypatch.setattr(llm_client, "_report_usage", _noop_report)
    monkeypatch.setattr(llm_client, "_maybe_report_recovery", _noop_report)
    monkeypatch.setattr(llm_client_mod.settings, "llm_temperature", 0.0)
    monkeypatch.setattr(llm_client_mod.settings, "llm_max_tokens", 100)
    monkeypatch.setattr(llm_client_mod.settings, "llm_model", "default-model")
    await llm_client.chat([{"role": "user", "content": "hi"}], trace_id="t")


async def test_defaults_used_when_no_agent_context(monkeypatch):
    captured = {}
    await _run_chat(monkeypatch, captured)
    kw = captured["call"].captured
    assert kw["temperature"] == 0.0
    assert kw["max_tokens"] == 100
    assert kw["model"] == "default-model"


async def test_agent_sampling_overrides_defaults(monkeypatch):
    set_agent_sampling(0.7, 2048, "agent-model")
    captured = {}
    await _run_chat(monkeypatch, captured)
    kw = captured["call"].captured
    assert kw["temperature"] == 0.7
    assert kw["max_tokens"] == 2048
    assert kw["model"] == "agent-model"


def test_get_agent_sampling_roundtrip():
    assert get_agent_sampling() == (None, None, None)
    set_agent_sampling(0.3, 512, "m")
    assert get_agent_sampling() == (0.3, 512, "m")
    set_agent_sampling(None, None, None)
    assert get_agent_sampling() == (None, None, None)