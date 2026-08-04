"""问诊聊天 HTTP 入口，业务编排位于 ``workflows.chat_workflow``。"""
import json

from fastapi import APIRouter, Depends, HTTPException, status
from sse_starlette.sse import EventSourceResponse

from app.core.security import require_internal_token, require_mobile_student
from app.models.chat import ChatRequest
from app.workflows.chat_workflow import chat_workflow

router = APIRouter()


@router.post("/v1/ai/chat/stream")
async def chat_stream(req: ChatRequest, student_id: int = Depends(require_mobile_student)):
    if req.student_id is not None and req.student_id != student_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="studentId 与登录用户不一致")
    return EventSourceResponse(
        chat_workflow.run(req, student_id),
        ping=15,
        headers={"X-Accel-Buffering": "no"},
    )


@router.post("/v1/internal/chat/sync")
async def chat_sync(req: ChatRequest, _t: None = Depends(require_internal_token)):
    """内部同步问诊接口（供 Spring Boot 转发，X-Internal-Token 鉴权）。

    消费 ``chat_workflow.run()`` 的事件流，聚合为单次 JSON 响应：
    reply / treeNodes / citations / safetyBlocked / safetyReason。
    不改动现有 /v1/ai/chat/stream SSE 接口。
    """
    if req.student_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="student_id 不能为空")

    reply_parts: list[str] = []
    tree_nodes: list = []
    citations: list = []
    safety_blocked = False
    safety_reason: str | None = None
    error_message: str | None = None

    async for event in chat_workflow.run(req, req.student_id):
        ev = event.get("event")
        try:
            payload = json.loads(event.get("data") or "{}")
        except (json.JSONDecodeError, TypeError):
            continue
        if ev == "message":
            delta = payload.get("delta")
            if delta:
                reply_parts.append(delta)
        elif ev == "tree":
            tree_nodes = payload.get("nodes", tree_nodes)
        elif ev == "citation":
            citations = payload.get("citations", citations)
        elif ev == "safety":
            if payload.get("blocked"):
                safety_blocked = True
                safety_reason = payload.get("reason")
        elif ev == "error":
            error_message = payload.get("message", "AI问诊处理失败")

    if error_message is not None:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=error_message)

    return {
        "code": 0,
        "data": {
            "reply": "".join(reply_parts),
            "treeNodes": tree_nodes,
            "citations": citations,
            "safetyBlocked": safety_blocked,
            "safetyReason": safety_reason,
        },
    }
