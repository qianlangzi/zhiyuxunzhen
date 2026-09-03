"""错题 AI 归因（PRD 4.11 错题本 → 学习辅导）— 错题归因 Agent

POST /internal/mistake/analyze
输入单条错题（题目 + 学生答案 + 标准答案 + 错误类型），
输出「根因 + 通俗讲解 + 巩固方向标签 + 练习提示」。
由业务中台调用并持久化缓存；AI 不可用时返回 status=DEGRADED 的降级数据（不抛错），
调用方据此不落缓存、移动端展示可重试的友好提示。
"""
import uuid
from typing import Any

from fastapi import APIRouter, Depends
from logging import INFO, WARNING

from app.core.logging import get_logger, log_event, set_context, reset_context
from app.core.security import require_internal_token
from app.models.common import R
from app.models.mistake import MistakeAnalyzeRequest, MistakeAnalysisResult
from app.prompts.templates import mistake_analysis_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)
router = APIRouter()


def _to_user_msg(req: MistakeAnalyzeRequest) -> str:
    """把单条错题组装成给 LLM 的用户消息"""
    lines = [
        f"错题 ID：{req.mistakeId}",
        f"错误类型：{req.mistakeType}",
    ]
    if req.caseTitle:
        lines.append(f"病例/场景：{req.caseTitle}")
    if req.knowledgeTag:
        lines.append(f"关联知识点：{req.knowledgeTag}")
    if req.question:
        lines.append(f"题目/问诊目标：{req.question}")
    lines.append(f"学生作答：{req.studentAnswer or '（无）'}")
    lines.append(f"标准答案：{req.standardAnswer or '（无）'}")
    if req.evidence:
        lines.append(f"关键证据/脱轨节点：{req.evidence}")
    lines.append("请基于以上信息，输出结构化错题归因 JSON。")
    return "\n".join(lines)


def _degraded(req: MistakeAnalyzeRequest) -> MistakeAnalysisResult:
    """LLM 不可用时的降级结果：不虚构内容，仅提示稍后重试"""
    return MistakeAnalysisResult(
        mistakeId=req.mistakeId,
        rootCause="",
        explanation="AI 归因服务暂时不可用，请稍后重试。",
        recommendedTags=[],
        practiceHint="",
        source="RULE",
        status="DEGRADED",
    )


@router.post("/internal/mistake/analyze", response_model=R)
async def analyze_mistake(
    req: MistakeAnalyzeRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        messages = [
            {"role": "system", "content": mistake_analysis_prompt()},
            {"role": "user", "content": _to_user_msg(req)},
        ]
        try:
            result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            log_event(logger, WARNING, "mistake_analysis_unavailable",
                      trace_id=trace_id, error=type(exc).__name__)
            return R(data=_degraded(req).model_dump())

        if not isinstance(result, dict) or not result.get("rootCause"):
            log_event(logger, WARNING, "mistake_analysis_invalid",
                      trace_id=trace_id, raw=str(result)[:200])
            return R(data=_degraded(req).model_dump())

        analysis = MistakeAnalysisResult(
            mistakeId=req.mistakeId,
            rootCause=str(result.get("rootCause") or ""),
            explanation=str(result.get("explanation") or ""),
            recommendedTags=[str(t) for t in (result.get("recommendedTags") or [])
                            if str(t).strip()][:5],
            practiceHint=str(result.get("practiceHint") or ""),
            source="AI",
            status="SUCCESS",
        )
        log_event(logger, INFO, "mistake_analysis_done",
                  trace_id=trace_id, mistake_id=req.mistakeId)
        return R(data=analysis.model_dump())
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "mistake_analysis_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e)[:200])
        return R(data=_degraded(req).model_dump())
    finally:
        reset_context()
