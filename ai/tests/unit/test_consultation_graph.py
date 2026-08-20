"""consultation_graph 节点单元测试。

验证 sp_reply 节点：走带工具的 SP 流式回复，并正确产出 stage / message 事件。
"""
import asyncio
import sys

import pytest

sys.path.insert(0, ".")

from app.workflows.consultation_graph import sp_reply


async def _collect(node, state):
    """运行节点并收集 event_sink 里的全部事件。"""
    events = []

    async def drain():
        while True:
            ev = await state["event_sink"].get()
            if ev is None:
                break
            events.append(ev)

    task = asyncio.create_task(drain())
    update = await node(state)
    await state["event_sink"].put(None)
    await task
    return update, events


@pytest.mark.asyncio
async def test_sp_reply_node_streams_via_tools(monkeypatch):
    async def fake_tools(*args, **kwargs):
        for word in ["你好", "，", "我是", "病人"]:
            yield word

    monkeypatch.setattr(
        "app.workflows.consultation_graph.sp_reply_stream_with_tools", fake_tools
    )

    sink = asyncio.Queue()
    state = {
        "case_context": "{}",
        "history": [],
        "trace_id": "t",
        "event_sink": sink,
    }
    update, events = await _collect(sp_reply, state)

    assert update["reply"] == "你好，我是病人"
    assert update["stage"] == "主诉采集"

    message_events = [e for e in events if e["event"] == "message"]
    assert len(message_events) == 4  # noqa: PLR2004

    stage_events = [e for e in events if e["event"] == "stage"]
    assert len(stage_events) == 1