"""SP Agent 的 LangGraph 状态边界。

LangGraph 是可选运行依赖：开发环境未安装时由 ChatWorkflow 使用同一节点逻辑，
生产安装 requirements 后即可通过 `build_sp_graph().ainvoke(...)` 使用图编排。
"""
from typing import Any, TypedDict

from app.agents.sp_agent import sp_reply_stream

try:
    from langgraph.graph import END, StateGraph
except ImportError:  # pragma: no cover - dependency is installed in the worker image
    END = "__end__"
    StateGraph = None


class SpState(TypedDict, total=False):
    case_context: str
    history: list[dict[str, str]]
    trace_id: str
    reply: str


async def generate_reply(state: SpState) -> dict[str, str]:
    parts: list[str] = []
    async for delta in sp_reply_stream(state.get("case_context", ""), state.get("history", []), state.get("trace_id", "-")):
        parts.append(delta)
    return {"reply": "".join(parts)}


def build_sp_graph() -> Any:
    if StateGraph is None:
        return None
    graph = StateGraph(SpState)
    graph.add_node("generate_reply", generate_reply)
    graph.set_entry_point("generate_reply")
    graph.add_edge("generate_reply", END)
    return graph.compile()
