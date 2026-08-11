"""问诊聊天工作流（基于 LangGraph 状态机）。

工作流负责会话边界、安全检查、RAG、SP 回复、持久化和 Mentor 增量更新的
编排。真正的图与节点在 ``consultation_graph`` 中定义；本模块只负责：
1. 建立 SSE 事件通道（asyncio.Queue）
2. 用后台任务驱动 LangGraph 图执行
3. 消费事件通道并 yield 给 SSE 客户端
4. 收尾发 done 事件

SSE 事件契约（message / tree / stage / socrates / safety / citation /
status / error / done）保持不变，供 /v1/ai/chat/stream 与 /internal/chat/sync 复用。
"""
import asyncio
import time
import uuid
from collections.abc import AsyncIterator
from logging import INFO, WARNING

from app.core.logging import get_logger, log_event, reset_context, set_context
from app.models.chat import ChatRequest
from app.workflows.consultation_graph import (
    build_consultation_graph,
    build_history,  # noqa: F401  # 重导出，供 session.py 等旧调用方使用
    sse,
)

logger = get_logger(__name__)


class ChatWorkflow:
    async def run(self, req: ChatRequest, student_id: int) -> AsyncIterator[dict[str, str]]:
        trace_id = str(uuid.uuid4())
        set_context(trace_id=trace_id, session_id=str(req.session_id))
        log_event(logger, INFO, "chat_start", trace_id=trace_id, session_id=req.session_id, case_id=req.case_id)

        sink: asyncio.Queue = asyncio.Queue()
        initial_state = {
            "req": req,
            "student_id": student_id,
            "trace_id": trace_id,
            "event_sink": sink,
        }
        graph = build_consultation_graph()
        producer = asyncio.create_task(self._drive(graph, initial_state))
        try:
            while True:
                event = await sink.get()
                if event is None:  # 图中的哨兵：图执行完毕（含异常）
                    break
                yield event
        finally:
            await asyncio.gather(producer, return_exceptions=True)
            reset_context()

        yield sse("done", {"session_id": req.session_id, "ts": int(time.time())})

    async def _drive(self, graph, initial_state: dict) -> None:
        """后台驱动图执行；结束（含异常）时发哨兵。"""
        sink = initial_state["event_sink"]
        try:
            async for _ in graph.astream(initial_state, stream_mode="updates"):
                pass
        except Exception as exc:  # noqa: BLE001 - 图异常也要收尾，保证 done 事件
            log_event(logger, WARNING, "chat_graph_error",
                      error=type(exc).__name__, msg=str(exc)[:300])
            await sink.put(sse("error", {"code": "GRAPH_ERROR", "message": "AI问诊处理失败"}))
        finally:
            await sink.put(None)


chat_workflow = ChatWorkflow()