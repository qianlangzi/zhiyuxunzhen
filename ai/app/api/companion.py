"""AI 学伴 HTTP 入口（P1-2，学习陪伴）。

- POST /v1/ai/companion/stream：SSE 流式（移动端直连），事件 message/status/safety/error/done
- POST /internal/companion/stream：内部流式（SSE），供 Spring Boot 代理转发给移动端
- POST /internal/companion/sync：内部同步（聚合为单次 JSON，供测试/Web 端）
"""
import json

from fastapi import APIRouter, Depends, HTTPException, status
from sse_starlette.sse import EventSourceResponse

from app.core.security import require_internal_token, require_mobile_student
from app.models.companion import CompanionChatRequest
from app.workflows.companion_workflow import companion_workflow

router = APIRouter()


@router.post("/v1/ai/companion/stream")
async def companion_stream(req: CompanionChatRequest,
                           student_id: int = Depends(require_mobile_student)):
    """SSE 流式学伴对话（学生端直连）。

    JWT 解析出的学生 ID 回填请求体——学伴的长期记忆/偏好按学生隔离，
    companion_workflow 依赖 req.student_id（此前恒为 None，记忆无从索引）。
    """
    req.student_id = student_id
    return EventSourceResponse(
        companion_workflow(req),
        ping=15,
        headers={"X-Accel-Buffering": "no"},
    )


@router.post("/internal/companion/stream")
async def companion_stream_internal(req: CompanionChatRequest,
                                    _t: None = Depends(require_internal_token)):
    """内部流式学伴对话（SSE），供 Spring Boot 代理转发给移动端。

    事件契约：message / status / safety / error / done。
    """
    return EventSourceResponse(
        companion_workflow(req),
        ping=15,
        headers={"X-Accel-Buffering": "no"},
    )


@router.post("/internal/companion/sync")
async def companion_sync(req: CompanionChatRequest,
                         _t: None = Depends(require_internal_token)):
    """内部同步学伴对话（聚合 SSE 为单次 JSON，供测试/Web 端）。"""
    reply_parts: list[str] = []
    safety_blocked = False
    safety_reason: str | None = None
    degraded = False
    error_message: str | None = None

    async for event in companion_workflow(req):
        ev = event.get("event")
        try:
            payload = json.loads(event.get("data") or "{}")
        except (json.JSONDecodeError, TypeError):
            continue
        if ev == "message":
            delta = payload.get("delta")
            if delta:
                reply_parts.append(delta)
        elif ev == "safety":
            if payload.get("blocked"):
                safety_blocked = True
                safety_reason = payload.get("reason")
        elif ev == "status":
            degraded = bool(payload.get("degraded")) or degraded
        elif ev == "error":
            error_message = payload.get("message", "AI 学伴处理失败")

    if error_message is not None:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=error_message)

    return {
        "code": 0,
        "data": {
            "reply": "".join(reply_parts),
            "safetyBlocked": safety_blocked,
            "safetyReason": safety_reason,
            "degraded": degraded,
            "source": "RULE" if degraded else "AI",
            "status": "DEGRADED" if degraded else "SUCCESS",
        },
    }
