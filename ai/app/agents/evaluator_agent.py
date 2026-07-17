"""Evaluator Agent：OSCE 四维评分 + 错题生成（PRD 4.9）"""
from typing import Any

from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.prompts.templates import evaluator_agent_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)


async def evaluate(
    case_context: str,
    history: list[dict[str, str]],
    trace_id: str = "-",
) -> dict[str, Any]:
    """问诊结束后评分

    返回字段：
        scores: {history, logic, communication, humanity}
        comments: 同上 4 维评语
        strengths: list[str]
        improvements: list[str]
        final_report: str
        mistakes: list[dict]
    """
    user_msg = (
        f"病例配置：\n{case_context}\n\n"
        f"完整对话历史：\n{history}\n\n"
        "请按 schema 输出评分 JSON。"
    )
    messages = [
        {"role": "system", "content": evaluator_agent_prompt()},
        {"role": "user", "content": user_msg},
    ]
    result = await llm_client.chat_json(messages, trace_id=trace_id)
    if not isinstance(result, dict) or "scores" not in result:
        log_event(logger, WARNING, "evaluator_invalid",
                  trace_id=trace_id, raw=str(result)[:200])
        return _fallback_eval()
    # 规范化 4 维分数
    scores = result.get("scores", {})
    for k in ("history", "logic", "communication", "humanity"):
        v = scores.get(k, 0)
        try:
            scores[k] = max(0, min(25, float(v)))
        except (TypeError, ValueError):
            scores[k] = 0
    result["scores"] = scores
    result.setdefault("comments", {})
    result.setdefault("strengths", [])
    result.setdefault("improvements", [])
    result.setdefault("final_report", "")
    result.setdefault("mistakes", [])
    log_event(logger, INFO, "evaluator_done",
              trace_id=trace_id, total=sum(scores.values()))
    return result


def _fallback_eval() -> dict[str, Any]:
    """LLM 不可用时的兜底评分"""
    return {
        "scores": {"history": 15, "logic": 12, "communication": 18, "humanity": 18},
        "comments": {
            "history": "（降级模式）未能精确分析病史采集完整性",
            "logic": "（降级模式）未能精确分析诊断逻辑",
            "communication": "（降级模式）默认中等偏上",
            "humanity": "（降级模式）默认中等偏上",
        },
        "strengths": ["完成了一次完整问诊训练"],
        "improvements": ["配置真实 LLM 后可获得详细改进建议"],
        "final_report": "本次评分基于降级模式，仅作联调验证用。",
        "mistakes": [],
    }
