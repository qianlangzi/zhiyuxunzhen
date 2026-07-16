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

from fastapi import APIRouter
from fastapi.responses import StreamingResponse

from app.agents.mentor_agent import update_tree as mentor_update
from app.agents.sp_agent import sp_reply_stream
from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.models.chat import ChatRequest
from app.services.rag_service import rag_service

logger = get_logger(__name__)
router = APIRouter()

# 教学场景的简单安全词列表（生产环境应由管理端维护）
_SAFETY_KEYWORDS = (
    "自杀", "自残", "自伤", "杀", "毒品", "制毒", "配方", "剂量",
)


def _sse(event: str, data: dict[str, Any]) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def _safety_check(text: str) -> bool:
    return any(k in text for k in _SAFETY_KEYWORDS)


def _build_history(messages: list) -> list[dict[str, str]]:
    """把 ChatMessage 列表转为 LLM messages（role/content）"""
    out: list[dict[str, str]] = []
    for m in messages:
        role = "assistant" if m.role in ("sp", "mentor", "system") else "user"
        out.append({"role": role, "content": m.content})
    return out


async def _chat_stream(req: ChatRequest) -> AsyncIterator[str]:
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id, session_id=str(req.session_id))
    log_event(logger, INFO, "chat_start",
              trace_id=trace_id, session_id=req.session_id,
              case_id=req.case_id, msgs=len(req.messages))

    try:
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
        history = _build_history(req.messages)
        # 病例上下文：暂时使用学生最后 5 条消息拼装（生产应从 Spring Boot 拉取病例配置）
        case_context = f"会话 {req.session_id} 的病例配置（生产环境应从业务中台拉取）：\n" + \
                       " | ".join(m.content[:50] for m in req.messages[:3])
        sp_text_parts: list[str] = []
        async for delta in sp_reply_stream(case_context, history, trace_id=trace_id):
            sp_text_parts.append(delta)
            yield _sse("message", {"delta": delta})

        sp_text = "".join(sp_text_parts)
        log_event(logger, INFO, "sp_reply_done",
                  trace_id=trace_id, length=len(sp_text))

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
async def chat_stream(req: ChatRequest):
    return StreamingResponse(
        _chat_stream(req),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # 关闭 Nginx 缓冲
            "Connection": "keep-alive",
        },
    )
