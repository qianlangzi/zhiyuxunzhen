"""个性化补救路径生成（PRD 9.3）

POST /learning_path/generate
由于无学生历史数据访问权限，本接口从业务中台拉取薄弱知识点（接口预留），
当前以 LLM 综合推荐 + RAG 检索教材页码为主。
"""
import uuid
from typing import Any

from fastapi import APIRouter, Depends

from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token
from app.models.common import R
from app.models.review import LearningPathRequest, LearningPathResult
from app.prompts.templates import learning_path_prompt
from app.services.llm_client import llm_client
from app.services.rag_service import rag_service
from app.core.errors import ModelUnavailableError, OutputSchemaInvalidError
from app.core.errors import ApiError

logger = get_logger(__name__)
router = APIRouter()


@router.post("/learning_path/generate", response_model=R)
async def generate_learning_path(
    req: LearningPathRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        # 用 LLM 综合推荐（生产环境应从业务中台拉取该学生的薄弱知识点和错题历史）
        user_msg = (
            f"学生 ID：{req.studentId}\n"
            "请基于内科教学常见薄弱点，生成一份通用补救路径。"
            "若 RAG 提供教材溯源，必须包含书名与章节。"
        )
        messages = [
            {"role": "system", "content": learning_path_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        if not isinstance(result, dict) or "recommendedSteps" not in result:
            log_event(logger, WARNING, "learning_path_invalid",
                      trace_id=trace_id, raw=str(result)[:200])
            raise OutputSchemaInvalidError(trace_id=trace_id) from None

        # 用 RAG 补充教材溯源
        query = "、".join(result.get("weakKnowledgeTags", [])[:3]) or "内科常见薄弱点"
        citations = await rag_service.search(query, top_k=3, trace_id=trace_id)
        result["citations"] = [c.model_dump() for c in citations]

        path = LearningPathResult(
            studentId=req.studentId,
            weakKnowledgeTags=result.get("weakKnowledgeTags", []),
            recommendedSteps=result.get("recommendedSteps", []),
            recommendedCases=result.get("recommendedCases", []),
            citations=result["citations"],
        )
        log_event(logger, INFO, "learning_path_done",
                  trace_id=trace_id, student_id=req.studentId,
                  steps=len(path.recommendedSteps))
        return R(data=path.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "learning_path_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "learning_path_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"学习路径生成失败：{e}", data=None)
    finally:
        reset_context()
