"""AI 复盘报告生成（PRD 9.3）

POST /report/generate_review_pdf
返回结构化报告内容，PDF 由 Java 端渲染（避免 Python 端引入 PDF 生成库的复杂性）。
"""
import uuid
from typing import Any

from fastapi import APIRouter, Depends

from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.embed import ReportRequest, ReportResult
from app.prompts.templates import report_agent_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)
router = APIRouter()


@router.post("/report/generate_review_pdf", response_model=R)
async def generate_review_pdf(
    req: ReportRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id, session_id=str(req.sessionId))
    try:
        # 生产环境应从业务中台拉取会话历史、错题、评分作为输入
        user_msg = (
            f"会话 ID：{req.sessionId}\n"
            "请基于一次典型内科问诊训练，生成结构化复盘报告 JSON。"
            "训练概览应包含：病例主题、问诊时长（估算）、错题数、四维评分。"
        )
        messages = [
            {"role": "system", "content": report_agent_prompt()},
            {"role": "user", "content": user_msg},
        ]
        result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)

        if not isinstance(result, dict) or "title" not in result:
            log_event(logger, WARNING, "report_invalid",
                      trace_id=trace_id, raw=str(result)[:200])
            result = _fallback_report(req.sessionId)

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
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "report_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"复盘报告生成失败：{e}", data=None)
    finally:
        reset_context()


def _fallback_report(session_id: int) -> dict[str, Any]:
    return {
        "title": f"会话 {session_id} 复盘报告（降级模式）",
        "overview": "本次复盘基于降级模式生成，仅作联调验证用。",
        "typicalMistakes": ["请配置真实 LLM 后重新生成报告以获得详细错题"],
        "standardPath": [],
        "textbookRefs": [],
        "nextSteps": ["配置 LLM_BASE_URL / LLM_API_KEY 后重新生成"],
    }
