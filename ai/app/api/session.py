"""会话评估与归档（PRD 9.4）

POST /session/evaluate_and_archive
Spring Boot 调用，需 X-Internal-Token 鉴权。

编排 evaluator_agent 评估后，依次调用 archive_session / sync_mistakes 回调业务中台。
"""
import uuid

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.agents.evaluator_agent import evaluate as evaluator_evaluate
from app.core.errors import ApiError
from app.core.logging import get_logger, log_event, reset_context, set_context
from app.core.security import require_internal_token
from app.models.common import R
from app.services.backend_client import backend_client
from logging import INFO, WARNING

logger = get_logger(__name__)
router = APIRouter()


class EvaluateArchiveRequest(BaseModel):
    sessionId: int
    studentId: int


@router.post("/session/evaluate_and_archive", response_model=R)
async def evaluate_and_archive(
    req: EvaluateArchiveRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        # 1. 获取会话上下文
        context = await backend_client.session_context(
            req.sessionId, req.studentId, trace_id,
        )
        if context is None:
            log_event(logger, WARNING, "session_context_unavailable",
                      trace_id=trace_id, session_id=req.sessionId)
            return R(code=404, message="获取会话上下文失败", data=None)

        case_context = context.get("case_context", "")
        messages = context.get("messages", [])

        # 2. AI 评估
        result = await evaluator_evaluate(case_context, messages, trace_id)
        scores = result["scores"]

        # 3. 归档会话（不阻塞响应）
        ok = await backend_client.archive_session(
            session_id=req.sessionId,
            osce_score=scores,
            final_report=result.get("final_report", ""),
            reasoning_tree=result,
            trace_id=trace_id,
        )
        log_event(logger, INFO, "archive_session",
                  trace_id=trace_id, session_id=req.sessionId, ok=ok)

        # 4. 同步错题本（若有）
        mistakes = result.get("mistakes", [])
        if mistakes:
            await backend_client.sync_mistakes(mistakes, trace_id)

        # 评估器未产生薄弱知识点数据，暂不调用 sync_weakness

        return R(data={"evaluated": True, "scores": scores})
    except ApiError as e:
        log_event(logger, WARNING, "evaluate_archive_api_error",
                  trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "evaluate_archive_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"评估归档失败：{e}", data=None)
    finally:
        reset_context()