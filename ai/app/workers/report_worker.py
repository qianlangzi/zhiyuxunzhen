"""基于 Spring Boot 会话事实生成结构化复盘报告。"""
import json
from typing import Any

from app.adapters.model_gateway import model_gateway
from app.core.errors import BackendDependencyError, ModelUnavailableError, OutputSchemaInvalidError
from app.prompts.templates import report_agent_prompt
from app.services.backend_client import backend_client
from app.services.llm_client import LlmFallbackError
from app.workers.base_worker import TaskWorker
from app.workers.task_queue import TaskQueue


async def handle_report(payload: dict[str, Any]) -> dict[str, Any]:
    session_id = int(payload.get("sessionId", 0))
    trace_id = payload.get("traceId", "-")
    if session_id <= 0:
        raise OutputSchemaInvalidError("报告任务缺少有效 sessionId", trace_id)
    context = await backend_client.report_context(session_id, trace_id)
    if context is None:
        raise BackendDependencyError("无法获取报告会话事实", trace_id)
    messages = [
        {"role": "system", "content": report_agent_prompt()},
        {"role": "user", "content": "请严格根据以下会话事实生成结构化复盘报告 JSON，不得补造事实：\n" + json.dumps(context, ensure_ascii=False)},
    ]
    try:
        result = await model_gateway.chat_json(messages, trace_id=trace_id)
    except LlmFallbackError as exc:
        raise ModelUnavailableError(trace_id=trace_id) from exc
    required = {"title", "overview", "typicalMistakes", "standardPath", "textbookRefs", "nextSteps"}
    if not isinstance(result, dict) or not required.issubset(result):
        raise OutputSchemaInvalidError("报告模型输出字段不完整", trace_id)
    return {"sessionId": session_id, **result}


def create_report_worker(queue: TaskQueue) -> TaskWorker:
    return TaskWorker(queue, "report", handle_report)
