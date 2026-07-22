"""AI 复盘报告生成（PRD 9.3）

POST /report/generate_review_pdf
返回结构化报告内容，PDF 由 Java 端渲染（避免 Python 端引入 PDF 生成库的复杂性）。
"""
import uuid
from typing import Any

from fastapi import APIRouter, Depends, Request

from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.embed import ReportRequest, ReportResult
from app.prompts.templates import report_agent_prompt
from app.services.llm_client import llm_client
from app.core.errors import ModelUnavailableError, OutputSchemaInvalidError
from app.core.errors import ApiError
from app.services.backend_client import backend_client
from app.core.errors import BackendDependencyError
from app.domain.enums import TaskType
from app.workers.task_models import TaskEnvelope
from app.workers.task_queue import TaskQueue

logger = get_logger(__name__)
router = APIRouter()


@router.post("/report/generate_review_pdf/async", response_model=R)
async def enqueue_review_report(
    req: ReportRequest,
    request: Request,
    _token: None = Depends(require_internal_token),
):
    task = await TaskQueue(getattr(request.app.state, "redis_client", None)).enqueue(
        TaskEnvelope(
            idempotency_key=f"report:{req.sessionId}",
            task_type=TaskType.REPORT,
            payload={"sessionId": req.sessionId},
        )
    )
    return R(data={"taskId": task.task_id, "status": task.status.value})


@router.post("/report/generate_review_pdf", response_model=R)
async def generate_review_pdf(
    req: ReportRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id, session_id=str(req.sessionId))
    try:
        context = await backend_client.report_context(req.sessionId, trace_id=trace_id)
        if context is None:
            raise BackendDependencyError("无法获取报告会话事实", trace_id)
        user_msg = (
            "请严格基于以下 Spring Boot 会话事实生成结构化复盘报告 JSON，"
            "禁止补造问诊时长、错题、评分或教材来源：\n"
            f"{context}"
        )
        messages = [
            {"role": "system", "content": report_agent_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        if not isinstance(result, dict) or "title" not in result:
            log_event(logger, WARNING, "report_invalid",
                      trace_id=trace_id, raw=str(result)[:200])
            raise OutputSchemaInvalidError(trace_id=trace_id) from None

        report = ReportResult(
            sessionId=req.sessionId,
            title=result.get("title", f"会话 {req.sessionId} 复盘报告"),
            overview=result.get("overview", ""),
            typicalMistakes=result.get("typicalMistakes", []),
            standardPath=result.get("standardPath", []),
            textbookRefs=result.get("textbookRefs", []),
            nextSteps=result.get("nextSteps", []),
        )
        log_event(logger, INFO, "report_done",
                  trace_id=trace_id, session_id=req.sessionId,
                  mistakes=len(report.typicalMistakes))
        return R(data=report.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "report_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "report_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"复盘报告生成失败：{e}", data=None)
    finally:
        reset_context()
