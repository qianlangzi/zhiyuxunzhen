"""大病历批阅（PRD 9.3）

POST /review/medical_record
Spring Boot 调用，需 X-Internal-Token 鉴权。

同步返回批阅结果，同时异步回调业务中台写入 medical_record_review 表。
"""
import uuid

from fastapi import APIRouter, Depends, Request

from app.agents.reviewer_agent import review as do_review
from app.core.logging import ensure_trace_id, get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.review import ReviewRequest, ReviewResult
from app.services.backend_client import backend_client
from app.core.errors import ApiError
from app.domain.enums import TaskType
from app.workers.task_models import TaskEnvelope
from app.workers.task_queue import TaskQueue

logger = get_logger(__name__)
router = APIRouter()


@router.post("/review/medical_record/async", response_model=R)
async def enqueue_medical_record_review(
    req: ReviewRequest,
    request: Request,
    _token: None = Depends(require_internal_token),
):
    """Submit a review task and return immediately; the legacy sync route remains unchanged."""
    queue = TaskQueue(getattr(request.app.state, "redis_client", None))
    task = await queue.enqueue(TaskEnvelope(
        idempotency_key=f"review:{req.instanceId}",
        task_type=TaskType.REVIEW,
        payload={
            "instanceId": req.instanceId,
            "medicalRecordText": req.medicalRecordText,
        },
    ))
    return R(data={"taskId": task.task_id, "status": task.status.value})


@router.post("/review/medical_record", response_model=R)
async def review_medical_record(
    req: ReviewRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        result = await do_review(
            medical_record_text=req.medicalRecordText,
            case_context=None,
            trace_id=trace_id,
        )
        # 同步返回结果
        review_result = ReviewResult(
            instanceId=req.instanceId,
            totalScore=result["totalScore"],
            mistakes=result["mistakes"],
            reviewComment=result["reviewComment"],
        )

        # 异步回调业务中台写入批阅记录（不阻塞响应）
        ok = await backend_client.review_callback(
            instance_id=req.instanceId,
            total_score=result["totalScore"],
            mistakes=result["mistakes"],
            review_comment=result["reviewComment"],
            trace_id=trace_id,
        )
        log_event(logger, INFO, "review_callback",
                  trace_id=trace_id, instance_id=req.instanceId, ok=ok)

        return R(data=review_result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "review_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "review_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"批阅失败：{e}", data=None)
    finally:
        reset_context()
