"""Reviewer Agent：大病历批阅（PRD 4.4）"""
from typing import Any

from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.prompts.templates import reviewer_agent_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)


async def review(
    medical_record_text: str,
    case_context: str | None = None,
    trace_id: str = "-",
) -> dict[str, Any]:
    """批阅大病历

    返回字段：
        totalScore: float 0-100
        mistakes: list[{location, type, severity, comment, deduction}]
        reviewComment: str
    """
    user_msg = (
        f"病例配置（可选）：\n{case_context or '未提供'}\n\n"
        f"待批阅大病历：\n{medical_record_text}\n\n"
        "请按 schema 输出批阅 JSON。"
    )
    messages = [
        {"role": "system", "content": reviewer_agent_prompt()},
        {"role": "user", "content": user_msg},
    ]
    result = await llm_client.chat_json(messages, trace_id=trace_id)
    if not isinstance(result, dict) or "totalScore" not in result:
        log_event(logger, WARNING, "reviewer_invalid",
                  trace_id=trace_id, raw=str(result)[:200])
        return _fallback_review()
    try:
        result["totalScore"] = max(0.0, min(100.0, float(result.get("totalScore", 0))))
    except (TypeError, ValueError):
        result["totalScore"] = 60.0
    result.setdefault("mistakes", [])
    result.setdefault("reviewComment", "")
    log_event(logger, INFO, "reviewer_done",
              trace_id=trace_id, score=result["totalScore"],
              mistakes=len(result["mistakes"]))
    return result


def _fallback_review() -> dict[str, Any]:
    """LLM 不可用时的兜底批阅"""
    return {
        "totalScore": 70.0,
        "mistakes": [
            {
                "location": "全文",
                "type": "other",
                "severity": "low",
                "comment": "（降级模式）未能精确识别文书/医学/逻辑问题，请配置真实 LLM 后重新批阅",
                "deduction": 0.0,
            }
        ],
        "reviewComment": "本次批阅基于降级模式，仅作联调验证用。",
    }
