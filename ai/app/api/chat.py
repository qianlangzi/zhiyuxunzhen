"""
多模态问诊室 - SSE 流式输出 (对应 PRD 4.2 / 8.2)

本文件只提供最小可运行骨架:
1. 接收前端 POST /api/v1/ai/chat/stream
2. 返回 SSE 事件: message / tree / done

真实生产需要把 SP Agent / Mentor Agent 接入 LangGraph 状态机
并对接科大讯飞星火大模型(见 app/core/spark_client.py 待补)
"""
import asyncio
import json
import time
from typing import AsyncIterator

from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

router = APIRouter()


class ChatMessage(BaseModel):
    role: str            # "student" | "sp" | "mentor" | "system"
    content: str


class ChatRequest(BaseModel):
    case_id: int
    session_id: int
    messages: list[ChatMessage]
    image_url: str | None = None
    image_bbox: list[float] | None = None   # [x, y, w, h] 相对坐标, PRD 5.2


async def _mock_stream(req: ChatRequest) -> AsyncIterator[str]:
    """MVP 假流:每 80ms 推一个 token,用于前端联调 SSE 管道"""
    last = req.messages[-1].content if req.messages else ""
    reply = f"[SP Mock] 已收到你的问题:「{last}」。真实 SP Agent 待接入星火大模型后启用。"

    # 1) SSE event: tree —— 思维决策树增量更新(PRD 4.7)
    tree_payload = {
        "nodes": [
            {"id": "n1", "type": "symptom", "label": "主诉:" + last[:8], "status": "queried"}
        ],
        "edges": []
    }
    yield f"event: tree\ndata: {json.dumps(tree_payload, ensure_ascii=False)}\n\n"

    # 2) SSE event: message —— 打字机效果
    for i, ch in enumerate(reply):
        await asyncio.sleep(0.05)
        yield f"event: message\ndata: {json.dumps({'delta': ch}, ensure_ascii=False)}\n\n"

    # 3) SSE event: done
    yield f"event: done\ndata: {json.dumps({'session_id': req.session_id, 'ts': int(time.time())})}\n\n"


@router.post("/v1/ai/chat/stream")
async def chat_stream(req: ChatRequest):
    return StreamingResponse(
        _mock_stream(req),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no"
        }
    )
