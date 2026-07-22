"""问诊聊天工作流。

工作流负责会话边界、安全检查、RAG、SP 回复、持久化和 Mentor 增量更新。
路由层不包含这些业务决策，便于后续替换为 LangGraph 编排。
"""
import json
import time
import uuid
from collections.abc import AsyncIterator
from logging import INFO, WARNING
from typing import Any

from app.agents.mentor_agent import update_tree as mentor_update
from app.agents.sp_agent import sp_reply_stream
from app.core.config import settings
from app.core.errors import RetrievalUnavailableError
from app.core.logging import get_logger, log_event, reset_context, set_context
from app.models.chat import ChatRequest
from app.services.backend_client import backend_client
from app.services.rag_service import rag_service

logger = get_logger(__name__)
_SAFETY_KEYWORDS = ("自杀", "自残", "杀", "毒品", "制毒", "配方", "剂量")


def sse(event: str, data: dict[str, Any]) -> dict[str, str]:
    return {"event": event, "data": json.dumps(data, ensure_ascii=False)}


def safety_blocked(text: str) -> bool:
    return any(keyword in text for keyword in _SAFETY_KEYWORDS)


def build_history(messages: list[Any]) -> list[dict[str, str]]:
    history: list[dict[str, str]] = []
    for message in messages:
        if isinstance(message, dict):
            sender = str(message.get("sender", message.get("role", "student"))).lower()
            content = str(message.get("content", ""))
        else:
            sender = message.role.lower()
            content = message.content
        if content:
            history.append({"role": "assistant" if sender in ("sp", "mentor", "system") else "user", "content": content})
    return history


class ChatWorkflow:
    async def run(self, req: ChatRequest, student_id: int) -> AsyncIterator[dict[str, str]]:
        trace_id = str(uuid.uuid4())
        set_context(trace_id=trace_id, session_id=str(req.session_id))
        log_event(logger, INFO, "chat_start", trace_id=trace_id, session_id=req.session_id, case_id=req.case_id)
        try:
            context = await backend_client.session_context(req.session_id, student_id, trace_id=trace_id)
            if context is None or int(context.get("caseId", -1)) != req.case_id:
                yield sse("error", {"code": "SESSION_FORBIDDEN", "message": "问诊会话不存在、已结束或不属于当前学生。"})
                yield sse("done", {"session_id": req.session_id, "ts": int(time.time())})
                return

            last_user = next((m.content for m in reversed(req.messages) if m.role == "student"), "")
            if safety_blocked(last_user):
                yield sse("safety", {"blocked": True, "reason": "检测到敏感内容，已按安全策略拦截。"})
                yield sse("done", {"session_id": req.session_id, "ts": int(time.time())})
                log_event(logger, WARNING, "chat_safety_blocked", trace_id=trace_id, session_id=req.session_id)
                return

            try:
                citations = await rag_service.search(last_user, top_k=3, trace_id=trace_id)
            except RetrievalUnavailableError:
                citations = []
                yield sse("status", {"degraded": True, "component": "retrieval", "message": "知识库暂不可用，本轮不提供教材引用。"})
            if citations:
                yield sse("citation", {"citations": [citation.model_dump() for citation in citations]})

            history = build_history(context.get("messages", []))
            if last_user and (not history or history[-1]["role"] != "user" or history[-1]["content"] != last_user):
                history.append({"role": "user", "content": last_user})
            case_context = json.dumps({
                "title": context.get("title"),
                "patientProfile": context.get("patientProfile"),
                "hiddenDisease": context.get("hiddenDisease"),
                "standardPath": context.get("standardPathJson"),
                "presetExams": context.get("presetExams"),
                "citations": [citation.model_dump() for citation in citations],
            }, ensure_ascii=False)
            if not settings.llm_configured:
                yield sse("status", {"degraded": True, "message": "当前未配置大模型，回复为规则降级结果。"})

            parts: list[str] = []
            async for delta in sp_reply_stream(case_context, history, trace_id=trace_id):
                parts.append(delta)
                yield sse("message", {"delta": delta})
            reply = "".join(parts)
            await backend_client.append_session_messages(req.session_id, student_id, [
                *([{"sender": "STUDENT", "content": last_user}] if last_user else []),
                *([{"sender": "SP", "content": reply}] if reply else []),
            ], trace_id=trace_id)

            try:
                tree = await mentor_update(case_context, history + [{"role": "assistant", "content": reply}], None, 0.0, trace_id)
                yield sse("tree", {"nodes": tree.get("nodes", []), "edges": tree.get("edges", [])})
                if tree.get("socrates_hint"):
                    yield sse("socrates", {"hint": tree["socrates_hint"]})
            except Exception as exc:  # noqa: BLE001
                log_event(logger, WARNING, "mentor_update_failed", trace_id=trace_id, error=type(exc).__name__)

            yield sse("done", {"session_id": req.session_id, "ts": int(time.time())})
        finally:
            reset_context()


chat_workflow = ChatWorkflow()
