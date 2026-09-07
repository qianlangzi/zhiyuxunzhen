"""每日一例判题（PRD 9.3 · 开放作答）

POST /daily_case/evaluate
开放作答：学生未做选择题，而是直接书写「诊断 + 依据 + 初步诊疗方案」，
由 LLM 对照病例的标准诊断要点（referenceAnswer / standardAnswer）评审。
Java 侧将病例 referenceAnswer 作为评分金标准通过 standardAnswer 字段传入。
"""
import uuid

from fastapi import APIRouter, Depends
from pydantic import Field

from app.core.logging import ensure_trace_id, get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.embed import DailyCaseEvaluateRequest, DailyCaseEvaluation
from app.prompts.templates import daily_case_prompt
from app.services.llm_client import llm_client
from app.core.errors import ApiError, OutputSchemaInvalidError

logger = get_logger(__name__)
router = APIRouter()


class DailyCaseFullRequest(DailyCaseEvaluateRequest):
    """扩展请求体：业务中台可附带病例原文供 LLM 判题"""

    caseSummary: str | None = Field(default=None, description="病例摘要/患者画像")
    keyFindings: str | None = Field(default=None, description="关键检查结果")
    standardAnswer: str | None = Field(default=None, description="标准诊断要点（评分金标准，供 LLM 评审，不做字符串相等判断）")


@router.post("/daily_case/evaluate", response_model=R)
async def evaluate_daily_case(
    req: DailyCaseFullRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # 开放作答一律走 LLM 对照标准诊断要点评审，避免选择题式字符串严格相等误判
        user_msg = (
            f"患者画像/病例摘要：\n{req.caseSummary or '未提供'}\n\n"
            f"关键检查结果：\n{req.keyFindings or '未提供'}\n\n"
            f"标准诊断要点（评分依据）：\n{req.standardAnswer or '未提供'}\n\n"
            f"学生开放作答（诊断/依据/诊疗方案）：\n{req.answer}\n\n"
            "请按 schema 输出判题 JSON。"
        )
        messages = [
            {"role": "system", "content": daily_case_prompt()},
            {"role": "user", "content": user_msg},
        ]
        result_dict = await llm_client.chat_json(messages, trace_id=trace_id)
        if not isinstance(result_dict, dict) or "correct" not in result_dict:
            log_event(logger, WARNING, "daily_case_invalid",
                      trace_id=trace_id, raw=str(result_dict)[:200])
            raise OutputSchemaInvalidError(trace_id=trace_id) from None

        result = DailyCaseEvaluation(
            studentId=req.studentId,
            caseId=req.caseId,
            correct=bool(result_dict.get("correct", False)),
            correctAnswer=result_dict.get("correctAnswer", ""),
            explanation=result_dict.get("explanation", ""),
            textbookRef=result_dict.get("textbookRef"),
        )
        log_event(logger, INFO, "daily_case_done",
                  trace_id=trace_id, student_id=req.studentId,
                  case_id=req.caseId, correct=result.correct)
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "daily_case_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "daily_case_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"判题失败：{e}", data=None)
    finally:
        reset_context()
