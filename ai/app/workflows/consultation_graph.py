"""门诊对话的 LangGraph 状态机编排。

把原来 ``chat_workflow`` 里的线性事件流改造成真正的多 Agent 图：

    load_context → safety_check → rag_search → sp_reply → output_check → persist → mentor_update

并带条件分支：
- load_context 校验失败（会话不存在/已结束/不属于当前学生）→ 直接结束
- safety_check 命中高危内容（BLOCK）→ 直接结束

LangGraph 只负责"编排顺序与条件分支"；每个节点是纯职责的 async 函数，
返回其对 state 的部分更新。需要推送给前端的 SSE 事件通过 state 里的
``event_sink``（asyncio.Queue）外发，由外层 ``run()`` 消费并 yield 给 SSE。

这样保留了原有 /v1/ai/chat/stream 与 /internal/chat/sync 的事件契约
（message / tree / stage / socrates / safety / citation / status / error / done）。
"""
from __future__ import annotations

import asyncio
import json
from typing import Any, TypedDict

from langgraph.graph import END, StateGraph

from app.agents.mentor_agent import update_tree as mentor_agent_update
from app.agents.sp_agent import sp_reply_stream_with_tools
from app.agents.toolkit import toolkit_list
from app.core.config import settings
from app.core.logging import get_logger
from app.domain.policies.output_policy import OutputCheckResult, output_policy
from app.domain.policies.safety_policy import SafetyDecision, safety_policy
from app.models.chat import ChatRequest
from app.services.backend_client import backend_client
from app.services.rag_service import rag_service

logger = get_logger(__name__)

# LLM 兜底/降级产物的文案前缀（见 llm_client._fallback_chat），用于避免假内容写入正式会话。
_DEGRADED_MARKER_PREFIX = "【降级模式】"


def sse(event: str, data: dict[str, Any]) -> dict[str, str]:
    return {"event": event, "data": json.dumps(data, ensure_ascii=False)}


def build_history(messages: list[Any]) -> list[dict[str, str]]:
    """把后端返回的消息历史转成 LLM 的 role/content 列表。"""
    history: list[dict[str, str]] = []
    for message in messages:
        if isinstance(message, dict):
            sender = str(message.get("sender", message.get("role", "student"))).lower()
            content = str(message.get("content", ""))
        else:
            sender = message.role.lower()
            content = message.content
        if content:
            history.append(
                {"role": "assistant" if sender in ("sp", "mentor", "system") else "user", "content": content}
            )
    return history


class ConsultationState(TypedDict, total=False):
    """问诊图的共享状态。"""

    req: ChatRequest
    student_id: int
    trace_id: str
    # 会话上下文
    context: dict[str, Any]
    last_user: str
    history: list[dict[str, str]]
    case_context: str
    citations: list[Any]
    # 决策结果
    safety_decision: SafetyDecision
    output_result: OutputCheckResult
    # SP 回复
    reply: str
    tree: dict[str, Any]
    stage: str
    socrates_hint: str | None
    # 异常标记（非 None 表示会话级错误，直接结束）
    error_code: str | None
    # SSE 事件通道（由外层 run() 注入）
    event_sink: asyncio.Queue


async def _emit(state: ConsultationState, event: str, data: dict[str, Any]) -> None:
    await state["event_sink"].put(sse(event, data))


# ---------------------------------------------------------------------------
# 节点
# ---------------------------------------------------------------------------
async def load_context(state: ConsultationState) -> dict[str, Any]:
    """读取并校验会话上下文；失败发 error 事件并置 error_code。"""
    req = state["req"]
    trace_id = state["trace_id"]
    context = await backend_client.session_context(
        req.session_id, state["student_id"], trace_id=trace_id
    )
    last_user = next((m.content for m in reversed(req.messages) if m.role == "student"), "")
    if context is None or int(context.get("caseId", -1)) != req.case_id:
        await _emit(
            state,
            "error",
            {"code": "SESSION_FORBIDDEN", "message": "问诊会话不存在、已结束或不属于当前学生。"},
        )
        return {"context": None, "last_user": last_user, "error_code": "SESSION_FORBIDDEN"}
    return {"context": context, "last_user": last_user, "error_code": None}


async def safety_check(state: ConsultationState) -> dict[str, Any]:
    """对输入做安全策略检查；DEFLECT 时发 status 事件。"""
    decision = safety_policy.check_input(state["last_user"])
    if decision.is_deflect:
        await _emit(state, "status", {"deflect": True, "message": decision.reason})
    return {"safety_decision": decision}


async def rag_search(state: ConsultationState) -> dict[str, Any]:
    """RAG 教材检索 + 组装 LLM 上下文（history / case_context / citations）。

    检索增强：
      - 查询改写开启（口语→医学术语 + 多轮指代消解，带对话历史）
      - 命中带图 chunk 时生成 VLM 图述并入 case_context（生成侧多模态）
    """
    trace_id = state["trace_id"]
    last_user = state["last_user"]
    ctx = state["context"]

    history = build_history(ctx.get("messages", []))
    if last_user and (not history or history[-1]["role"] != "user" or history[-1]["content"] != last_user):
        history.append({"role": "user", "content": last_user})

    try:
        citations = await rag_service.search(
            last_user, top_k=3, trace_id=trace_id,
            rewrite=True, history=history,
        )
    except Exception:  # noqa: BLE001 - 检索不可用降级，不阻断对话
        citations = []
        await _emit(
            state,
            "status",
            {"degraded": True, "component": "retrieval", "message": "知识库暂不可用，本轮不提供教材引用。"},
        )
    if citations:
        await _emit(state, "citation", {"citations": [c.model_dump() for c in citations]})

    # 生成侧多模态：命中带图 citation → VLM 图述并入上下文（失败静默）
    image_notes: list[str] = []
    if settings.image_caption_enabled:
        try:
            from app.services.image_index_service import image_index_service
            for c in citations:
                if getattr(c, "image_key", None):
                    note = await image_index_service.caption(
                        c.image_key, context=c.chunk_text or "", trace_id=trace_id,
                    )
                    if note:
                        image_notes.append(f"[{c.book_name} p{c.page_number} 配图] {note}")
        except Exception:  # noqa: BLE001 - 图述失败不影响对话
            pass

    case_context = json.dumps(
        {
            "title": ctx.get("title"),
            "patientProfile": ctx.get("patientProfile"),
            "hiddenDisease": ctx.get("hiddenDisease"),
            "standardPath": ctx.get("standardPathJson"),
            "presetExams": ctx.get("presetExams"),
            "citations": [c.model_dump() for c in citations],
            "imageNotes": image_notes,
        },
        ensure_ascii=False,
    )
    return {"citations": citations, "history": history, "case_context": case_context}


async def sp_reply(state: ConsultationState) -> dict[str, Any]:
    """SP 扮演病人流式回复（带工具调用：SP 可主动检索教材知识库）。

    每个增量通过 message 事件外发。未配置 LLM 时工具调用自动降级为无工具路径。
    """
    stage = "主诉采集"
    await _emit(state, "stage", {"stage": stage})
    parts: list[str] = []
    async for delta in sp_reply_stream_with_tools(
        state["case_context"],
        state["history"],
        toolkit_list(),
        trace_id=state["trace_id"],
        stage=stage,
    ):
        parts.append(delta)
        await _emit(state, "message", {"delta": delta})
    return {"reply": "".join(parts), "stage": stage}


async def output_check(state: ConsultationState) -> dict[str, Any]:
    """校验 SP 回复，防止泄露隐藏疾病/医学术语；BLOCK 时替换为安全拒答。"""
    reply = state["reply"]
    result = output_policy.validate_sp_reply(reply, hidden_disease=state["context"].get("hiddenDisease"))
    if not result.passed and result.action == "BLOCK":
        reply = "抱歉，我无法回答这个问题。"
        await _emit(state, "safety", {"blocked": True, "reason": result.reason})
    return {"output_result": result, "reply": reply}


async def persist(state: ConsultationState) -> dict[str, Any]:
    """把本次学生提问与 SP 回复写回业务中台。

    降级/兜底生成的合成文案不得写入正式的会话事实（否则假内容污染历史 / 复盘 / 评分）。
    """
    last_user = state["last_user"]
    reply = state["reply"]
    degraded = reply.startswith(_DEGRADED_MARKER_PREFIX)
    if degraded:
        # 本轮为 LLM 兜底生成，不入库，仅发状态事件便于前端提示
        await _emit(state, "status", {"degraded": True, "component": "llm",
                                      "message": "大模型暂不可用，本轮对话未保存。"})
        return {}

    await backend_client.append_session_messages(
        state["req"].session_id,
        state["student_id"],
        [
            *([{"sender": "STUDENT", "content": last_user}] if last_user else []),
            *([{"sender": "SP", "content": reply}] if reply else []),
        ],
        trace_id=state["trace_id"],
    )
    return {}


async def mentor_update(state: ConsultationState) -> dict[str, Any]:
    """Mentor 更新思维树、推进阶段、生成苏格拉底提示。失败不影响主流程。"""
    try:
        tree = await mentor_agent_update(
            state["case_context"],
            state["history"] + [{"role": "assistant", "content": state["reply"]}],
            None,
            0.0,
            state["trace_id"],
        )
        await _emit(state, "tree", {"nodes": tree.get("nodes", []), "edges": tree.get("edges", [])})
        new_stage = tree.get("current_stage")
        if new_stage and new_stage != state.get("stage"):
            await _emit(state, "stage", {"stage": new_stage})
        if tree.get("socrates_hint"):
            await _emit(state, "socrates", {"hint": tree["socrates_hint"]})
        return {
            "tree": tree,
            "stage": new_stage or state.get("stage"),
            "socrates_hint": tree.get("socrates_hint"),
        }
    except Exception as exc:  # noqa: BLE001 - 思维树失败不阻断对话
        logger.warning("consultation_graph.mentor_update failed: %s", exc)
        return {"tree": {"nodes": [], "edges": []}}


# ---------------------------------------------------------------------------
# 条件路由
# ---------------------------------------------------------------------------
def _route_after_load(state: ConsultationState) -> str:
    return "end" if state.get("error_code") else "proceed"


def _route_after_safety(state: ConsultationState) -> str:
    decision = state.get("safety_decision")
    return "end" if (decision and decision.is_blocked) else "proceed"


# ---------------------------------------------------------------------------
# 图构建
# ---------------------------------------------------------------------------
def build_consultation_graph() -> Any:
    """构建并编译问诊状态机。"""
    graph = StateGraph(ConsultationState)
    graph.add_node("load_context", load_context)
    graph.add_node("safety_check", safety_check)
    graph.add_node("rag_search", rag_search)
    graph.add_node("sp_reply", sp_reply)
    graph.add_node("output_check", output_check)
    graph.add_node("persist", persist)
    graph.add_node("mentor_update", mentor_update)

    graph.set_entry_point("load_context")
    graph.add_conditional_edges(
        "load_context", _route_after_load, {"proceed": "safety_check", "end": END}
    )
    graph.add_conditional_edges(
        "safety_check", _route_after_safety, {"proceed": "rag_search", "end": END}
    )
    graph.add_edge("rag_search", "sp_reply")
    graph.add_edge("sp_reply", "output_check")
    graph.add_edge("output_check", "persist")
    graph.add_edge("persist", "mentor_update")
    graph.add_edge("mentor_update", END)
    return graph.compile()