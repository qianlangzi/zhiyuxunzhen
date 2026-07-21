"""多模态问诊室 - SSE 流式输出（PRD 4.2 / 8.2 / 9.2）

事件格式：
- event: message    data: {"delta": "..."}        SP 回复增量
- event: tree       data: {"nodes":[],"edges":[]} 思维树增量更新
- event: socrates   data: {"hint": "..."}         苏格拉底提示
- event: safety     data: {"blocked": true}       安全拦截
- event: done       data: {"session_id": 0, "ts": 0}  结束
"""
import json
import time
import uuid
from collections.abc import AsyncIterator
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sse_starlette.sse import EventSourceResponse

from app.agents.mentor_agent import update_tree as mentor_update
from app.agents.sp_agent import sp_reply_stream
from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.models.chat import ChatRequest
from app.services.rag_service import rag_service
from app.services.backend_client import backend_client
from app.core.security import require_mobile_student
from app.core.config import settings

logger = get_logger(__name__)
router = APIRouter()

# 教学场景的简单安全词列表（生产环境应由管理端维护）
_SAFETY_KEYWORDS = (
    "自杀", "自残", "自伤", "杀", "毒品", "制毒", "配方", "剂量",
)


def _sse(event: str, data: dict[str, Any]) -> dict[str, str]:
    return {"event": event, "data": json.dumps(data, ensure_ascii=False)}


def _safety_check(text: str) -> bool:
    return any(k in text for k in _SAFETY_KEYWORDS)


def _build_history(messages: list) -> list[dict[str, str]]:
    """把客户端模型或后端持久化消息统一转换为 LLM messages。"""
    out: list[dict[str, str]] = []
    for m in messages:
        if isinstance(m, dict):
            sender = str(m.get("sender", m.get("role", "student"))).lower()
            content = str(m.get("content", ""))
        else:
            sender = m.role.lower()
            content = m.content
        role = "assistant" if sender in ("sp", "mentor", "system") else "user"
        if content:
            out.append({"role": role, "content": content})
    return out


async def _chat_stream(req: ChatRequest, student_id: int) -> AsyncIterator[dict[str, str]]:
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id, session_id=str(req.session_id))
    log_event(logger, INFO, "chat_start",
              trace_id=trace_id, session_id=req.session_id,
              case_id=req.case_id, msgs=len(req.messages))

    try:
        context = await backend_client.session_context(
            req.session_id, student_id, trace_id=trace_id
        )
        if context is None or int(context.get("caseId", -1)) != req.case_id:
            yield _sse("error", {
                "code": "SESSION_FORBIDDEN",
                "message": "问诊会话不存在、已结束或不属于当前学生。",
            })
            yield _sse("done", {"session_id": req.session_id, "ts": int(time.time())})
            return

        # 1. 安全检查学生最新输入
        last_user = next(
            (m.content for m in reversed(req.messages) if m.role == "student"),
            "",
        )
        if _safety_check(last_user):
            yield _sse("safety", {
                "blocked": True,
                "reason": "检测到敏感内容，已按安全策略拦截。",
            })
            yield _sse("done", {"session_id": req.session_id, "ts": int(time.time())})
            log_event(logger, WARNING, "chat_safety_blocked",
                      trace_id=trace_id, session_id=req.session_id)
            return

        # 2. 并行触发 RAG 检索（仅用于可选溯源，不阻塞主流程）
        citations = await rag_service.search(last_user, top_k=3, trace_id=trace_id)
        if citations:
            yield _sse("citation", {
                "citations": [c.model_dump() for c in citations]
            })

        # 3. SP 流式回复（主流程）
        # 历史以 Spring Boot 中已经持久化的消息为准，客户端只提供本轮最新输入。
        # 这样重装 App 或换设备后仍能继续同一会话，也不会信任客户端伪造历史。
        history = _build_history(context.get("messages", []))
        if last_user and (
            not history
            or history[-1]["role"] != "user"
            or history[-1]["content"] != last_user
        ):
            history.append({"role": "user", "content": last_user})
        case_context = json.dumps(
            {
                "title": context.get("title"),
                "patientProfile": context.get("patientProfile"),
                "hiddenDisease": context.get("hiddenDisease"),
                "standardPath": context.get("standardPathJson"),
                "presetExams": context.get("presetExams"),
            },
            ensure_ascii=False,
        )
        if not settings.llm_configured:
            yield _sse("status", {
                "degraded": True,
                "message": "当前未配置大模型，问诊回复为规则降级结果。",
            })
        sp_text_parts: list[str] = []
        async for delta in sp_reply_stream(case_context, history, trace_id=trace_id):
            sp_text_parts.append(delta)
            yield _sse("message", {"delta": delta})

        sp_text = "".join(sp_text_parts)
        log_event(logger, INFO, "sp_reply_done",
                  trace_id=trace_id, length=len(sp_text))

        if last_user or sp_text:
            await backend_client.append_session_messages(
                req.session_id,
                student_id,
                [
                    *([{"sender": "STUDENT", "content": last_user}] if last_user else []),
                    *([{"sender": "SP", "content": sp_text}] if sp_text else []),
                ],
                trace_id=trace_id,
            )

        # 4. Mentor 后台更新思维树（与主流程串行，避免 SSE 乱序）
        try:
            tree_update = await mentor_update(
                case_context=case_context,
                history=history + [{"role": "assistant", "content": sp_text}],
                current_tree=None,
                accumulated_cost=0.0,
                trace_id=trace_id,
            )
            yield _sse("tree", {
                "nodes": tree_update.get("nodes", []),
                "edges": tree_update.get("edges", []),
            })
            hint = tree_update.get("socrates_hint")
            if hint:
                yield _sse("socrates", {"hint": hint})
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "mentor_update_failed",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))

        # 5. 结束事件
        yield _sse("done", {"session_id": req.session_id, "ts": int(time.time())})
        log_event(logger, INFO, "chat_done", trace_id=trace_id, session_id=req.session_id)
    finally:
        reset_context()


@router.post("/v1/ai/chat/stream")
async def chat_stream(
    req: ChatRequest,
    student_id: int = Depends(require_mobile_student),
):
    if req.student_id is not None and req.student_id != student_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="studentId 与登录用户不一致",
        )
    return EventSourceResponse(
        _chat_stream(req, student_id),
        ping=15,
        headers={"X-Accel-Buffering": "no"},
    )
