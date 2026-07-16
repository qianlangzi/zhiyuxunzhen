"""Mentor Agent：维护思维树 + 苏格拉底式提示（PRD 4.7 / 4.8）

输入：学生最新消息 + 病例标准路径 + 累计费用
输出：增量思维树 JSON + 可选的苏格拉底提示
"""
from typing import Any

from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.prompts.templates import mentor_agent_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)


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
    result = await llm_client.chat_json(messages, trace_id=trace_id)
    # 兜底：LLM 不可用或返回异常时返回空树
    if not isinstance(result, dict) or "nodes" not in result:
        log_event(logger, WARNING, "mentor_tree_invalid",
                  trace_id=trace_id, raw=str(result)[:200])
        return {"nodes": [], "edges": [], "socrates_hint": None}
    log_event(logger, INFO, "mentor_tree_updated",
              trace_id=trace_id, nodes=len(result.get("nodes", [])))
    return result
