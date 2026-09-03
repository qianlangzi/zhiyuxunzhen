"""问诊聊天 HTTP 入口，业务编排位于 ``workflows.chat_workflow``。

端点：
- POST /v1/ai/chat/stream   SSE 流式（学生端 JWT 鉴权，移动端暂未直连）
- POST /internal/chat/sync   内部同步（X-Internal-Token，Spring Boot 聚合后下发移动端）
- POST /internal/chat/stream 内部流式（X-Internal-Token，Spring Boot 透传给移动端，SSE 打字机）

事件契约保持完全一致：message / tree / citation / safety / stage / socrates / status / error / done。
新增 stream 接口零业务改动，复用 chat_workflow.run() 的 async generator。
"""
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


@router.post("/internal/chat/stream")
async def chat_stream_internal(req: ChatRequest,
                               _t: None = Depends(require_internal_token)):
    """内部流式问诊（SSE）· 供 Spring Boot 透传给移动端。

    与 ``/internal/chat/sync`` 平行，按事件逐条转发到客户端，前端可在打字机模式下
    边收边渲染。事件契约与 sync 一致，零业务改动。
    失败处理：工作流内部会发 ``error`` + ``done`` 事件，SSE 通道保持打开，移动端据此
    展示兜底文案；不直接 500，方便前端做"加载失败重试"而不是页面崩溃。
    """
    if req.student_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="student_id 不能为空")
    return EventSourceResponse(
        chat_workflow.run(req, req.student_id),
        ping=15,
        headers={"X-Accel-Buffering": "no"},
    )


@router.post("/internal/chat/opening")
async def chat_opening(req: ChatRequest,
                       _t: None = Depends(require_internal_token)):
    """SP 开场白（PRD 5.2 优化）· 学生首次进入会话时调用一次。

    与 chat_sync 区别：
    - 不要求 messages 字段（history 视为空）
    - **不写** ChatMessageLog、不更新 ChatSession、不送 mentor_update。
      仅一次性流式生成 SP 开场白，由 Spring Boot 透传给移动端做首屏播放。
    - case_context 为空时仍能输出（依赖 _OPENING_GUIDE 引导），AI 不可用兜底为
      一句保守开场。

    返回格式：``{code:0, data:{reply, degraded, source, status}}``
    """
    if req.student_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="student_id 不能为空")
    if req.case_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="case_id 不能为空")

    from app.agents.sp_agent import sp_reply_stream
    from app.services.backend_client import backend_client
    # 开场必须携带真实病例上下文，否则 SP 无论开哪个病例都会用「无主诉」
    # 的同一句中性/幻觉开场（表现为不同病例却在同一部位疼痛）。
    # 注意：这里不能按 session_id 回查会话上下文——会话刚创建时 Spring Boot
    # 外层事务可能尚未提交，回查必得 1404「会话不存在」，case_context 恒为空，
    # SP 只能编造主诉。开场仅需病例内容，因此直接按 case_id 拉取病例上下文，
    # 与正常问诊轮次使用的病例数据同源、且不依赖会话事务（2026-09-02 修复）。
    case_context = ""
    try:
        ctx = await backend_client.case_context(
            req.case_id, trace_id="opening-" + str(req.session_id)
        )
        if ctx:
            case_context = json.dumps(
                {
                    "title": ctx.get("title"),
                    "patientProfile": ctx.get("patientProfile"),
                    "hiddenDisease": ctx.get("hiddenDisease"),
                    "standardPath": ctx.get("standardPathJson"),
                    "presetExams": ctx.get("presetExams"),
                },
                ensure_ascii=False,
            )
    except Exception:  # noqa: BLE001 - 拉取病例上下文失败也不阻断开场，退化为中性开场
        case_context = ""
    parts: list[str] = []
    degraded = False
    try:
        # 空病例上下文禁止调用 LLM：SP 没有病例可依时极易幻觉出一句泛化的
        # 「腰疼/肚子疼/胸口疼」开场（2026-09-02 曾因此被误判为 prompt 硬编码），
        # 宁可降级为保守开场也不让 SP 凭空捏造主诉。
        if not case_context:
            degraded = True
            raise RuntimeError("case_context empty, fallback to conservative opening")
        async for delta in sp_reply_stream(
            case_context=case_context,
            history=[],  # 历史为空 → build_sp_messages 注入主动开场引导
            trace_id="opening-" + str(req.session_id),
            stage="主诉采集",
        ):
            parts.append(delta)
    except Exception:  # noqa: BLE001 - LLM 不可用兜底为保守开场
        degraded = True
        parts = []

    reply = "".join(parts).strip()
    if not reply:
        # 兜底文案：教师讲义过的通用开场（既不暴露诊断也不喧宾夺主）
        reply = "医生您好，我最近一直不太舒服，想来找您看看。"
        degraded = True
    return {
        "code": 0,
        "data": {
            "reply": reply,
            "degraded": degraded,
            "source": "RULE" if degraded else "AI",
            "status": "DEGRADED" if degraded else "SUCCESS",
        },
    }


@router.post("/internal/chat/mentor")
async def chat_mentor(req: ChatRequest,
                      _t: None = Depends(require_internal_token)):
    """导师按需小结（2026-09-03）：按学生主动请求生成思维树 + 苏格拉底提示。

    训练态不在对话流里实时推送 mentor_update（live_mentor_hint_enabled=False，
    防剧透漏诊）；移动端通过左滑手势按需唤出时走本接口：
        session_context（病例 + 历史）→ mentor_agent.update_tree → {tree, hint}
    与实时流完全解耦，不影响问诊主链路；失败返回 degraded，移动端兜底提示。
    """
    if req.student_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="student_id 不能为空")
    if req.session_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="session_id 不能为空")

    from app.agents.mentor_agent import update_tree
    from app.workflows.consultation_graph import build_history
    from app.services.backend_client import backend_client

    trace_id = f"mentor-{req.session_id}"
    ctx = await backend_client.session_context(req.session_id, req.student_id, trace_id=trace_id)
    if ctx is None:
        return {
            "code": 0,
            "data": {"nodes": [], "edges": [], "socrates_hint": None,
                     "status": "FAILED", "degraded": True},
        }

    history = build_history(ctx.get("messages", []))
    case_context = json.dumps(
        {
            "title": ctx.get("title"),
            "patientProfile": ctx.get("patientProfile"),
            "hiddenDisease": ctx.get("hiddenDisease"),
            "standardPath": ctx.get("standardPathJson"),
            "presetExams": ctx.get("presetExams"),
        },
        ensure_ascii=False,
    )
    tree = await update_tree(case_context, history, None, 0.0, trace_id)
    return {
        "code": 0,
        "data": {
            "nodes": tree.get("nodes", []),
            "edges": tree.get("edges", []),
            "socratesHint": tree.get("socrates_hint"),
            "status": tree.get("status", "OK"),
            "degraded": tree.get("degraded", False),
        },
    }


@router.post("/internal/chat/sync")
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
    socrates_hint: str | None = None
    stage: str | None = None
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
        elif ev == "socrates":
            socrates_hint = payload.get("hint")
        elif ev == "stage":
            stage = payload.get("stage")
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
            "socratesHint": socrates_hint,
            "stage": stage,
        },
    }
