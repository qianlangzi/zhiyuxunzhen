"""每日一例判题（PRD 9.3）

POST /daily_case/evaluate
由于无业务中台病例数据访问权限，请求体扩展可选字段 caseSummary / keyFindings / standardAnswer，
若 Spring Boot 未传递则使用降级规则判题。
"""
import uuid
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import Field

from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.embed import DailyCaseEvaluateRequest, DailyCaseEvaluation
from app.prompts.templates import daily_case_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)
router = APIRouter()


class DailyCaseFullRequest(DailyCaseEvaluateRequest):
    """扩展请求体：业务中台可附带病例原文供 LLM 判题"""

    caseSummary: str | None = Field(default=None, description="病例摘要")
    keyFindings: str | None = Field(default=None, description="关键检查结果")
    standardAnswer: str | None = Field(default=None, description="标准答案，用于规则判题")


@router.post("/daily_case/evaluate", response_model=R)
async def evaluate_daily_case(
    req: DailyCaseFullRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        # 优先：业务中台已提供标准答案，走规则判题（最快、最稳）
        if req.standardAnswer:
            correct = req.answer.strip() == req.standardAnswer.strip()
            result_dict: dict[str, Any] = {
                "correct": correct,
                "correctAnswer": req.standardAnswer,
                "explanation": "基于业务中台标准答案的规则判题" if correct else "答案与标准答案不符，请检查要点",
                "textbookRef": None,
            }
        else:
            # 否则走 LLM 判题
            user_msg = (
                f"病例摘要：\n{req.caseSummary or '未提供'}\n\n"
                f"关键检查结果：\n{req.keyFindings or '未提供'}\n\n"
                f"学生答案：\n{req.answer}\n\n"
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
                result_dict = _fallback_eval(req.answer)

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
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "daily_case_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"判题失败：{e}", data=None)
    finally:
        reset_context()


def _fallback_eval(answer: str) -> dict[str, Any]:
    return {
        "correct": False,
        "correctAnswer": "（降级模式）未配置 LLM，无法精确判题",
        "explanation": "请配置真实 LLM 后重新判题。学生答案已记录。",
        "textbookRef": None,
    }
