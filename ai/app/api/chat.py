"""问诊聊天 HTTP 入口，业务编排位于 ``workflows.chat_workflow``。"""
from fastapi import APIRouter, Depends, HTTPException, status
from sse_starlette.sse import EventSourceResponse

from app.core.security import require_mobile_student
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
