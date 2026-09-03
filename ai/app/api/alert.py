"""学情预警：AI 干预建议生成接口（助教：学情精准诊断）

POST /insight/alert
- 输入：学生预警规则/薄弱点/近期错题/候选病例与教材
- LLM 只归纳输入中的真实数据，推荐病例/教材仅从候选中选择（防幻觉）
"""
import json
import uuid
from logging import INFO, WARNING

from fastapi import APIRouter, Depends

from app.core.errors import ApiError, ModelUnavailableError, OutputSchemaInvalidError
from app.core.logging import get_logger, log_event, reset_context, set_context
from app.core.security import require_internal_token
from app.domain.policies.safety_policy import safety_policy
from app.models.alert import AlertInterventionRequest, AlertInterventionResult
from app.models.common import R
from app.prompts.templates import alert_intervention_prompt
from app.services.llm_client import llm_client
from app.services.structured_output import structured_output

logger = get_logger(__name__)
router = APIRouter()


@router.post("/insight/alert", response_model=R)
async def alert_intervention(
    req: AlertInterventionRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        risk_text = json.dumps(req.riskRules or [], ensure_ascii=False)
        weakness_text = json.dumps(req.weaknesses or [], ensure_ascii=False)
        mistake_text = json.dumps(req.recentMistakes or [], ensure_ascii=False)
        case_text = json.dumps(req.recommendedCases or [], ensure_ascii=False)
        ref_text = json.dumps(req.textbookRefs or [], ensure_ascii=False)

        user_msg = (
            f"学生：{req.studentName}\n"
            f"触发的预警规则：{risk_text or '无'}\n"
            f"薄弱知识点：{weakness_text or '无'}\n"
            f"近期错题：{mistake_text or '无'}\n"
            f"候选病例（仅可从中推荐）：{case_text or '无'}\n"
            f"候选教材（仅可从中引用）：{ref_text or '无'}\n\n"
            "请按 schema 输出干预建议 JSON，只依据以上真实数据。"
        )
        messages = [
            {"role": "system", "content": alert_intervention_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: AlertInterventionResult = await structured_output.parse_and_validate(
            raw, AlertInterventionResult, trace_id=trace_id,
        )
        safety = safety_policy.check_output(json.dumps(result.model_dump(), ensure_ascii=False))
        if safety.is_blocked:
            raise OutputSchemaInvalidError("生成结果未通过安全校验", trace_id)

        log_event(logger, INFO, "alert_intervention_done", trace_id=trace_id,
                  student=req.studentName, rules=len(req.riskRules or []))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "alert_intervention_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "alert_intervention_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"干预建议生成失败：{e}", data=None)
    finally:
        reset_context()
