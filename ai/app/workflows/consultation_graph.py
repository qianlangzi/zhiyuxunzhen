"""门诊对话的 LangGraph 状态机编排。

把原来 ``chat_workflow`` 里的线性事件流改造成真正的多 Agent 图：

    load_context → safety_check → rag_search → exam_dispatch → sp_reply → output_check → persist → mentor_update

并带条件分支：
- load_context 校验失败（会话不存在/已结束/不属于当前学生）→ 直接结束
- safety_check 命中高危内容（BLOCK）→ 直接结束

LangGraph 只负责"编排顺序与条件分支"；每个节点是纯职责的 async 函数，
返回其对 state 的部分更新。需要推送给前端的 SSE 事件通过 state 里的
``event_sink``（asyncio.Queue）外发，由外层 ``run()`` 消费并 yield 给 SSE。

这样保留了原有 /v1/ai/chat/stream 与 /internal/chat/sync 的事件契约
（message / tree / stage / socrates / safety / citation / status / error / done / report）。
"""
from __future__ import annotations

import asyncio
import json
import operator
from typing import Annotated, Any, TypedDict

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
from app.services.exam_dispatch import (
    build_report,
    match_exams,
    parse_exam_menu,
    summary_for_sp,
)
from app.services.rag_service import rag_service

logger = get_logger(__name__)

# LLM 兜底/降级产物的文案前缀（见 llm_client._fallback_chat），用于避免假内容写入正式会话。
_DEGRADED_MARKER_PREFIX = "【降级模式】"

# 完整就诊阶段（SP 按此推进）
_ALL_STAGES = (
    "主诉采集", "现病史", "既往史", "查体", "辅助检查", "诊断", "治疗",
)

# 由最近对话推断当前阶段的规则（新消息优先命中）
_STAGE_KEYWORDS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("治疗", ("开药", "处方", "吃药", "用药", "药盒", "输液", "吊针", "打点滴", "手术", "住院", "治疗方案", "怎么治")),
    ("诊断", ("诊断", "确诊", "是什么病", "考虑什么", "初步考虑", "明确诊断")),
    ("辅助检查", ("检查", "化验", "抽血", "血常规", "心电图", "胸片", "ct", "b超", "彩超", "报告", "影像", "拍个", "做个")),
    ("查体", ("查体", "体格检查", "听诊", "叩诊", "触诊", "测血压", "测体温", "测心率")),
    ("现病史", ("现病史", "怎么回事", "什么时候开始", "怎么不舒服", "吃过什么药", "有没有发烧")),
    ("既往史", ("既往", "以前有", "糖尿病", "高血压", "过敏", "做过手术", "家族", "药物过敏")),
)


def detect_stage(history: list[dict[str, str]]) -> str:
    """根据最近对话推断当前问诊阶段（确定性启发式，供 SP / 输出校验使用）。

    从最新消息向前扫描，命中第一阶段关键词即返回；空历史或未命中回退主诉采集。
    """
    for message in reversed(history or []):
        content = (message.get("content", "") if isinstance(message, dict) else str(message))
        if not content:
            continue
        low = content.lower()
        for stage, kws in _STAGE_KEYWORDS:
            if any(kw in low for kw in kws):
                return stage
    return "主诉采集"


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
    # 本轮命中下发的检查报告卡（规则 + 工具兜底合并，Annotated reducer 累加）
    reports: Annotated[list[dict[str, Any]], operator.add]
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
    """对输入做安全策略检查；DEFLECT 时发 status 事件。

    本工作流是 SP 模拟病例问诊：开药/处方/手术/输液等都是训练目标话术，
    故以 is_sp_case=True 豁免 DEFLECT；自伤/他伤等高风险内容仍一律拦截。
    """
    decision = safety_policy.check_input(state["last_user"], is_sp_case=True)
    if decision.is_deflect:
        await _emit(state, "status", {"deflect": True, "message": decision.reason})
    return {"safety_decision": decision}


# ---- 引用分级（2026-09-03 严谨性治理：垂类 SP 问诊不允许"他病"引用流入）----
# 医患问答库 = 真实患者就医问答片段，常夹带无关疾病细节（探针实测甲状腺会话
# 检索出"流产/胎停育"条目），一旦进入 SP 语境/展示出处即构成驴唇不对马嘴 →
# SP 问诊链路一律剔除；OpenCMKG = 单病种结构化事实，可作 SP 语境但不出示为"教材出处"。
_TEXTBOOK_KEYWORDS = (
    "病理学", "诊断学", "内科学", "外科学", "妇产科学", "儿科学", "神经病学",
    "药理学", "解剖学", "生理学", "免疫学", "鉴别诊断", "医学影像",
)
_KB_ANECDOTE_MARK = "医患问答"
_KB_GRAPH_MARKS = ("OpenCMKG", "知识图谱")
_CITATION_GENERIC_BIGRAMS = frozenset({
    "检查", "相关", "做过", "最近", "请问", "您好", "可以", "需要", "这个", "什么",
    "怎么", "时候", "情况", "现在", "治疗", "症状", "疾病", "方面", "进行", "是否",
    "没有", "觉得", "知道", "医生", "患者", "我们", "一个", "一下", "有点", "有些",
})


def _cjk_bigrams(text: str) -> set[str]:
    chars = [ch for ch in (text or "") if "\u4e00" <= ch <= "\u9fff"]
    return {chars[i] + chars[i + 1] for i in range(len(chars) - 1)}


def _classify_citation(c: Any) -> str:
    """语料分级：textbook（权威教材）/ graph（结构化图谱）/ anecdote（真实问答）/ other。"""
    book = getattr(c, "book_name", None) or ""
    if _KB_ANECDOTE_MARK in book:
        return "anecdote"
    if any(mark in book for mark in _KB_GRAPH_MARKS):
        return "graph"
    # 无 book_name 的存量 chunk 保守按教材处理，避免展示功能整体消失
    if not book or any(kw in book for kw in _TEXTBOOK_KEYWORDS):
        return "textbook"
    return "other"


def _display_safe(c: Any, user_query: str) -> bool:
    """展示级引用门槛：仅权威教材，且与当轮问题存在实质词义重合。

    作用：挡掉向量检索的跨病种误命中（例：甲状腺会话检索到《病理学》
    结核病章节——文本全无甲状腺相关词，仅因对话历史含"咳嗽"被改写带偏）。
    """
    if _classify_citation(c) != "textbook":
        return False
    text = f"{getattr(c, 'chapter', '') or ''} {getattr(c, 'chunk_text', '') or ''}"
    overlap = _cjk_bigrams(user_query) & _cjk_bigrams(text)
    overlap -= _CITATION_GENERIC_BIGRAMS
    return bool(overlap)


async def rag_search(state: ConsultationState) -> dict[str, Any]:
    """RAG 教材检索 + 组装 LLM 上下文（history / case_context / citations）。

    检索增强：
      - 查询改写开启（口语→医学术语 + 多轮指代消解，带对话历史）
      - 命中带图 chunk 时生成 VLM 图述并入 case_context（生成侧多模态）

    引用分级（2026-09-03）：
      - 全量检索结果 → SP 语境（剔除 anecdote，防"他病"细节混入病例推理）
      - 展示给学生（citation 事件）→ 仅权威教材 + 词义重合门槛（防跨病种误命中）
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

    # 分级：语境用 = 剔除真实问答库；展示用 = 语境用中仅权威教材且词义重合
    grounding = [c for c in citations if _classify_citation(c) != "anecdote"]
    display = [c for c in grounding if _display_safe(c, last_user)]
    if display:
        await _emit(state, "citation", {"citations": [c.model_dump() for c in display]})

    # 生成侧多模态：命中带图 citation → VLM 图述并入上下文（失败静默）
    image_notes: list[str] = []
    if settings.image_caption_enabled:
        try:
            from app.services.image_index_service import image_index_service
            for c in grounding:
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
            "citations": [c.model_dump() for c in grounding],
            "imageNotes": image_notes,
        },
        ensure_ascii=False,
    )
    return {"citations": grounding, "history": history, "case_context": case_context}


async def exam_dispatch(state: ConsultationState) -> dict[str, Any]:
    """检查请求 → 病例预置报告卡（规则主路，2026-09-03 与老大拍板的质量锁）。

    学生本轮消息与病例 presetExams 做精确名/别名匹配；命中且有 result 才：
      ① 下发结构化报告卡（SSE `report` 事件），移动端确定性渲染（ecg 波形 /
         lab 表 / 影像）；② 把结果口语摘要追加到当轮 LLM 上下文，让 SP 用病人口
         吻自然转述。
    未命中或无 result → 当项检查等于没做（语义正确，天然防幻觉）。运行期绝不
    现场生图或编造数值：报告卡内容完全来自病例金标准。
    """
    user_text = state.get("last_user") or ""
    if not user_text:
        return {}
    context = state.get("context") or {}
    menu = parse_exam_menu(context.get("presetExams"))
    if not menu:
        return {}
    hits = match_exams(user_text, menu)
    if not hits:
        return {}
    reports: list[dict[str, Any]] = []
    notes: list[str] = []
    for item in hits:
        if not item.get("result"):
            continue
        report = build_report(item)
        reports.append(report)
        await _emit(state, "report", report)
        notes.append(summary_for_sp(item))
    if not reports:
        return {}
    # 仅当轮 LLM 可见（不写回持久化历史）；提示 SP 已完成检查并给出转述锚点
    note_block = "\n\n[本轮回合·刚完成的检查] " + "；".join(notes)
    case_context = (state.get("case_context") or "") + note_block
    return {"reports": reports, "case_context": case_context}


async def sp_reply(state: ConsultationState) -> dict[str, Any]:
    """SP 扮演病人流式回复（带工具调用：SP 可主动检索教材知识库/确认检查）。

    每个增量通过 message 事件外发。阶段由最近对话实时推导（替代写死的主诉采集），
    使 SP 能随问诊进展走向 查体→辅助检查→诊断→治疗。未配置 LLM 时工具调用自动降级。

    工具表根据病例 presetExams 动态构造（report_exam_result 兜底）；SP 调工具
    命中的报告卡通过 on_report 回调收集到 reports_local，由本节点统一下发 SSE
    `report` 事件，确保移动端拿到完整的图形化报告卡数据。
    """
    stage = detect_stage(state.get("history", []))
    await _emit(state, "stage", {"stage": stage})

    preset_raw = state["context"].get("presetExams") if state.get("context") else None
    reports_local: list[dict[str, Any]] = []

    def _on_report(report: dict[str, Any]) -> None:
        reports_local.append(report)

    tools = toolkit_list(preset_exams_raw=preset_raw, on_report=_on_report)

    parts: list[str] = []
    async for delta in sp_reply_stream_with_tools(
        state["case_context"],
        state["history"],
        tools,
        trace_id=state["trace_id"],
        stage=stage,
    ):
        parts.append(delta)
        await _emit(state, "message", {"delta": delta})

    # 工具兜底命中（规则未识别但 SP 主动调了 report_exam_result）的报告卡
    for r in reports_local:
        await _emit(state, "report", r)

    return {
        "reply": "".join(parts),
        "stage": stage,
        "reports": reports_local,
    }


async def output_check(state: ConsultationState) -> dict[str, Any]:
    """校验 SP 回复，防止泄露隐藏疾病/医学正确答案；BLOCK 时替换为安全拒答。

    辅助检查/诊断/治疗阶段（allow_clinical）下，放行检查结果汇报与治疗话术，
    但仍拦截隐藏疾病与系统提示词泄露。此阶段 SP 不必回避患者口中的化验描述。
    """
    reply = state["reply"]
    stage = detect_stage(state.get("history", []))
    allow_clinical = stage in ("辅助检查", "诊断", "治疗")
    result = output_policy.validate_sp_reply(
        reply, hidden_disease=state["context"].get("hiddenDisease"), allow_clinical=allow_clinical
    )
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
    """Mentor 更新思维树、推进阶段、生成苏格拉底提示。失败不影响主流程。

    训练态默认关闭（settings.live_mentor_hint_enabled=False）：不在问诊流中实时
    推送思维树/苏格拉底提示——实时暴露"漏了哪些采集点"会剧透诊断、破坏训练与
    OSCE 评估独立性；复盘思维树由结束时 evaluator 一并产出。开关可经管理端热开。
    """
    if not settings.live_mentor_hint_enabled:
        return {"tree": {"nodes": [], "edges": []}}
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
    graph.add_node("exam_dispatch", exam_dispatch)
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
    graph.add_edge("rag_search", "exam_dispatch")
    graph.add_edge("exam_dispatch", "sp_reply")
    graph.add_edge("sp_reply", "output_check")
    graph.add_edge("output_check", "persist")
    graph.add_edge("persist", "mentor_update")
    graph.add_edge("mentor_update", END)
    return graph.compile()