"""错题智能推荐（PRD 4.10.x）

POST /internal/recommend/weakness
由业务中台在错题板块调用：传入学生薄弱知识点，AI 生成个性化补救建议
（优先复习顺序、学习路径、推荐题与教材侧重点）。
LLM 不可用时降级返回规则化建议，不阻断学生端。
"""
import uuid
from logging import INFO, WARNING
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.errors import ApiError
from app.core.logging import ensure_trace_id, get_logger, log_event, reset_context, set_context
from app.core.security import require_internal_token
from app.models.common import R
from app.prompts.templates import recommendation_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)
router = APIRouter()


class RecommendRequest(BaseModel):
    knowledgeTags: list[str] = Field(default_factory=list, description="薄弱知识点")
    mistakes: list[str] = Field(default_factory=list, description="近期错题要点（可选）")
    candidateTextbooks: list[str] = Field(default_factory=list, description="候选教材标题（防幻觉，仅限从中推荐）")
    candidateQuestions: list[str] = Field(default_factory=list, description="候选基础题标题（防幻觉，仅限从中推荐）")


@router.post("/internal/recommend/weakness", response_model=R)
async def recommend_weakness(
    req: RecommendRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        tags = req.knowledgeTags or ["内科基础"]
        user_msg = (
            "学生近期薄弱知识点：" + "、".join(tags) + "\n"
            "近期错题要点：" + ("、".join(req.mistakes) if req.mistakes else "无") + "\n"
            "可参考的候选教材（推荐教材/章节请只从这些标题中选择）：" +
            ("、".join(req.candidateTextbooks) if req.candidateTextbooks else "暂无") + "\n"
            "可参考的候选基础题（推荐刷题请只从这些中选择）：" +
            ("、".join(req.candidateQuestions) if req.candidateQuestions else "暂无") + "\n"
            "请给出个性化的补救建议，必须包含：\n"
            "1) 优先复习的知识点排序及理由；\n"
            "2) 推荐的刷题方向（难度进阶安排）；\n"
            "3) 建议核对的教材/章节。"
        )
        messages = [
            {"role": "system", "content": recommendation_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)
            if not isinstance(result, dict) or "advice" not in result:
                raise ValueError("缺少 advice 字段")
            result.setdefault("status", "OK")
            result.setdefault("source", "LLM")
            result.setdefault("degraded", False)
        except Exception:  # noqa: BLE001
            # LLM 不可用或输出不规范 → 规则化降级
            result = fallback(tags, req.mistakes)

        log_event(logger, INFO, "recommend_weakness_done",
                  trace_id=trace_id, tags=len(tags))
        return R(data=result)
    except ApiError as e:
        log_event(logger, WARNING, "recommend_weakness_unavailable",
                  trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=fallback(req.knowledgeTags, req.mistakes))
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "recommend_weakness_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"智能推荐生成失败：{e}", data=fallback(req.knowledgeTags, req.mistakes))
    finally:
        reset_context()


def fallback(tags: list[str], mistakes: list[str]) -> dict[str, Any]:
    """规则化降级建议：按知识点去重排序，给出刷题与教材方向。"""
    tags = [t for t in (tags or []) if t and t.strip()]
    if not tags:
        tags = ["内科基础"]
    return {
        "advice": "AI 暂时不可用，以下为基于薄弱知识点的规则化建议。",
        "status": "DEGRADED",
        "source": "RULE",
        "degraded": True,
        "priority": tags,
        "studyPlan": "建议先专项刷题巩固基础题（简单→标准→困难进阶），再结合对应教材章节复盘。",
        "mistakesNote": "、".join(mistakes) if mistakes else "无"
    }
