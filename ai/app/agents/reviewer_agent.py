"""Medical-record reviewer. It never invents a score when the model is unavailable."""
from typing import Any
from logging import INFO, WARNING

from app.adapters.model_gateway import model_gateway
from app.core.errors import ModelUnavailableError, OutputSchemaInvalidError
from app.core.logging import get_logger, log_event
from app.prompts.templates import reviewer_agent_prompt
from app.services.llm_client import LlmFallbackError

logger = get_logger(__name__)


async def review(medical_record_text: str, case_context: str | None = None, trace_id: str = "-") -> dict[str, Any]:
    messages = [
        {"role": "system", "content": reviewer_agent_prompt()},
        {"role": "user", "content": f"病例配置：\n{case_context or '未提供'}\n\n待批阅病历：\n{medical_record_text}\n\n请按 schema 输出批阅 JSON。"},
    ]
    try:
        result = await model_gateway.chat_json(messages, trace_id=trace_id)
    except LlmFallbackError as exc:
        raise ModelUnavailableError(trace_id=trace_id) from exc
    if not isinstance(result, dict) or "totalScore" not in result:
        log_event(logger, WARNING, "reviewer_invalid", trace_id=trace_id)
        raise OutputSchemaInvalidError(trace_id=trace_id)
    try:
        result["totalScore"] = max(0.0, min(100.0, float(result["totalScore"])))
    except (TypeError, ValueError) as exc:
        raise OutputSchemaInvalidError("批阅结果 totalScore 不是有效数字", trace_id=trace_id) from exc
    result.setdefault("mistakes", [])
    result.setdefault("reviewComment", "")
    log_event(logger, INFO, "reviewer_done", trace_id=trace_id, score=result["totalScore"])
    return result
