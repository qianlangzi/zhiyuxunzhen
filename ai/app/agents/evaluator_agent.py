"""OSCE evaluator. Missing model output is an unavailable evaluation, not a score."""
from typing import Any
from logging import INFO

from app.adapters.model_gateway import model_gateway
from app.core.errors import ModelUnavailableError, OutputSchemaInvalidError
from app.core.logging import get_logger, log_event
from app.prompts.templates import evaluator_agent_prompt
from app.services.llm_client import LlmFallbackError

logger = get_logger(__name__)
_DIMENSIONS = ("history", "logic", "communication", "humanity")


async def evaluate(case_context: str, history: list[dict[str, str]], trace_id: str = "-") -> dict[str, Any]:
    messages = [
        {"role": "system", "content": evaluator_agent_prompt()},
        {"role": "user", "content": f"病例配置：\n{case_context}\n\n完整对话历史：\n{history}\n\n请按 schema 输出评分 JSON。"},
    ]
    try:
        result = await model_gateway.chat_json(messages, trace_id=trace_id)
    except LlmFallbackError as exc:
        raise ModelUnavailableError(trace_id=trace_id) from exc
    if not isinstance(result, dict) or not isinstance(result.get("scores"), dict):
        raise OutputSchemaInvalidError(trace_id=trace_id)
    scores = result["scores"]
    for dimension in _DIMENSIONS:
        if dimension not in scores:
            raise OutputSchemaInvalidError(f"评分结果缺少维度: {dimension}", trace_id=trace_id)
        try:
            scores[dimension] = max(0.0, min(25.0, float(scores[dimension])))
        except (TypeError, ValueError) as exc:
            raise OutputSchemaInvalidError(f"评分维度 {dimension} 不是有效数字", trace_id=trace_id) from exc
    result["scores"] = scores
    result.setdefault("comments", {})
    result.setdefault("strengths", [])
    result.setdefault("improvements", [])
    result.setdefault("final_report", "")
    result.setdefault("mistakes", [])
    log_event(logger, INFO, "evaluator_done", trace_id=trace_id, total=sum(scores.values()))
    return result
