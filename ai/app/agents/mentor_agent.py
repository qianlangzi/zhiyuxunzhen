"""Mentor Agent：维护思维树 + 苏格拉底式提示（PRD 4.7 / 4.8）

输入：学生最新消息 + 病例标准路径 + 累计费用
输出：增量思维树 JSON + 可选的苏格拉底提示
"""
from typing import Any

from app.core.errors import OutputSchemaInvalidError
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.prompts.templates import mentor_agent_prompt
from app.adapters.model_gateway import model_gateway

logger = get_logger(__name__)

# 导师思维树输出长（十几到二十个节点，每节点带 evidence 原文），而线上主模型
# 是推理型（deepseek-v4-flash）：思维链与正文共享同一份 max_tokens 预算。
# 实测 max_tokens=1024 时思维链独占全部预算 → finish_reason=length 且正文为空
# → 结构化解析必然失败 → 移动端「提示」恒为空（2026-09-10 定位）。
# 因此本 Agent 显式给足预算，并关闭思维链（结构化作答不需要思维链）。
_MENTOR_MAX_TOKENS = 3072
# 兜底重试预算：若网关不支持关闭思维链（或换模型后思维链再度膨胀），
# 首次解析失败时加倍预算重试一次，把硬失败降级为"慢一点但成功"。
_MENTOR_RETRY_MAX_TOKENS = 6144


async def _invoke(messages: list[dict[str, str]], max_tokens: int, trace_id: str) -> dict[str, Any]:
    """按导师预算调用结构化输出（关闭思维链）。"""
    return await model_gateway.chat_json(
        messages,
        max_tokens=max_tokens,
        disable_thinking=True,
        trace_id=trace_id,
    )


async def update_tree(
    case_context: str,
    history: list[dict[str, str]],
    current_tree: dict[str, Any] | None,
    accumulated_cost: float,
    trace_id: str = "-",
) -> dict[str, Any]:
    """分析学生最新提问，返回更新后的思维树 JSON

    返回字段：
        nodes: list[dict]
        edges: list[dict]
        socrates_hint: str | None
    """
    user_msg = (
        f"病例标准路径：\n{case_context}\n\n"
        f"当前思维树：\n{current_tree or {'nodes': [], 'edges': []}}\n\n"
        f"累计检查费用：{accumulated_cost} 元\n\n"
        f"对话历史：\n{history}\n\n"
        "请输出更新后的思维树 JSON。"
    )
    messages = [
        {"role": "system", "content": mentor_agent_prompt()},
        {"role": "user", "content": user_msg},
    ]
    try:
        try:
            result = await _invoke(messages, _MENTOR_MAX_TOKENS, trace_id)
        except OutputSchemaInvalidError:
            log_event(logger, WARNING, "mentor_tree_retry", trace_id=trace_id,
                      reason="schema_invalid", max_tokens=_MENTOR_RETRY_MAX_TOKENS)
            result = await _invoke(messages, _MENTOR_RETRY_MAX_TOKENS, trace_id)
    except Exception as exc:  # noqa: BLE001
        log_event(logger, WARNING, "mentor_tree_failed", trace_id=trace_id,
                  error=type(exc).__name__)
        return {"nodes": [], "edges": [], "socrates_hint": None,
                "status": "FAILED", "source": "NONE", "degraded": True}
    # 兜底：LLM 不可用或返回异常时返回空树
    if not isinstance(result, dict) or "nodes" not in result:
        log_event(logger, WARNING, "mentor_tree_invalid",
                  trace_id=trace_id, raw=str(result)[:200])
        return {"nodes": [], "edges": [], "socrates_hint": None,
                "status": "FAILED", "source": "NONE", "degraded": True}
    result.setdefault("status", "OK")
    result.setdefault("source", "LLM")
    result.setdefault("degraded", False)
    log_event(logger, INFO, "mentor_tree_updated",
              trace_id=trace_id, nodes=len(result.get("nodes", [])))
    return result
