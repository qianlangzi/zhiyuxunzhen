"""主观题（简答/论述）批阅接口（助教：作业与试题批改）

POST /review/essay
- 输入：题目 + 教师自定义评分要点 + 学生答案 +（可选）病例上下文/RAG 锚点
- LLM 按评分要点逐条核验，输出维度评分 + 错误明细 + 综合评语
- 教师复核后入库（复用现有批阅复核流程）
"""
import json
import uuid
from logging import INFO, WARNING

from fastapi import APIRouter, Depends

from app.core.errors import ApiError, ModelUnavailableError, OutputSchemaInvalidError, RetrievalUnavailableError
from app.core.logging import ensure_trace_id, get_logger, log_event, reset_context, set_context
from app.core.security import require_internal_token
from app.domain.policies.safety_policy import safety_policy
from app.models.common import R
from app.models.essay import EssayReviewRequest, EssayReviewResult
from app.prompts.templates import essay_reviewer_prompt
from app.services.llm_client import llm_client
from app.services.rag_service import rag_service
from app.services.structured_output import structured_output

logger = get_logger(__name__)
router = APIRouter()


@router.post("/review/essay", response_model=R)
async def review_essay(
    req: EssayReviewRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # 以题目检索教材，作为评分依据锚点（可选增强）
        citations = []
        try:
            citations = await rag_service.search(req.question, top_k=3, trace_id=trace_id)
        except RetrievalUnavailableError:
            log_event(logger, WARNING, "essay_review_rag_unavailable", trace_id=trace_id)

        rag_text = "\n".join(
            f"- 《{c.book_name}》·{c.chapter or ''}·P{c.page_number or ''}：{(c.chunk_text or '')[:300]}"
            for c in citations
        ) or "（未检索到教材内容）"

        user_msg = (
            f"题目：{req.question}\n"
            f"教师评分要点：{req.scoringPoints or '（未配置，请按医学主观题通用标准评阅）'}\n"
            f"学生答案：\n{req.studentAnswer}\n"
            f"病例/题干上下文：{req.caseContext or '无'}\n\n"
            f"教材参考（可作为评分依据）：\n{rag_text}\n\n"
            "请按 schema 输出批阅 JSON。"
        )
        messages = [
            {"role": "system", "content": essay_reviewer_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: EssayReviewResult = await structured_output.parse_and_validate(
            raw, EssayReviewResult, trace_id=trace_id,
        )
        safety = safety_policy.check_output(json.dumps(result.model_dump(), ensure_ascii=False))
        if safety.is_blocked:
            raise OutputSchemaInvalidError("批阅结果未通过安全校验", trace_id)

        log_event(logger, INFO, "essay_review_done", trace_id=trace_id,
                  score=result.totalScore, dimensions=len(result.dimensions))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "essay_review_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "essay_review_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"主观题批阅失败：{e}", data=None)
    finally:
        reset_context()
