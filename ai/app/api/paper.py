"""AI 组卷（P2-4 学生自测卷 · AI 选题组卷）

POST /internal/paper/generate
输入学生薄弱知识点 + 题库候选（审核通过的真实题目），LLM 从候选中选题组卷，
返回自测卷标题 + 选中题目 ID + 组卷思路。题目内容由业务中台按 ID 解析，AI 不生成题目（防幻觉）。
AI 不可用时返回 status=DEGRADED 的降级结果（不抛错），调用方回退规则组卷。
"""
import uuid
from logging import INFO, WARNING
from typing import Any

from fastapi import APIRouter, Depends

from app.core.logging import ensure_trace_id, get_logger, log_event, set_context, reset_context
from app.core.security import require_internal_token
from app.models.common import R
from app.models.paper import PaperGenerateRequest, PaperGenerateResult
from app.prompts.templates import paper_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)
router = APIRouter()


def _to_user_msg(req: PaperGenerateRequest) -> str:
    """把薄弱点 + 候选题目组装成给 LLM 的用户消息"""
    lines = [
        f"学生 ID：{req.studentId}",
        f"目标题量：{req.count}",
        f"难度偏好：{req.difficulty if req.difficulty else '不限'}",
        f"薄弱知识点：{'、'.join(req.focusTags) if req.focusTags else '（暂无统计，按通用组卷）'}",
        "候选题目列表：",
    ]
    for c in req.candidates:
        diff = {1: "简单", 2: "标准", 3: "困难"}.get(c.difficulty, "未知")
        lines.append(
            f"- id={c.id} | {c.knowledgeTag or '未知'} | {diff} | {c.questionType or 'unknown'} | {c.title or '（无题干）'}"
        )
    if not req.candidates:
        lines.append("（无候选题目）")
    lines.append("请基于以上信息，输出结构化组卷 JSON（只从候选中选题，禁止编造）。")
    return "\n".join(lines)


def _degraded(req: PaperGenerateRequest) -> PaperGenerateResult:
    """LLM 不可用时的降级结果：返回空选题，由调用方回退规则组卷"""
    return PaperGenerateResult(
        paperTitle="",
        selectedIds=[],
        rationale="AI 组卷服务暂时不可用，已使用规则组卷兜底。",
        source="RULE",
        status="DEGRADED",
    )


@router.post("/internal/paper/generate", response_model=R)
async def generate_paper(
    req: PaperGenerateRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        messages = [
            {"role": "system", "content": paper_prompt()},
            {"role": "user", "content": _to_user_msg(req)},
        ]
        try:
            result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            log_event(logger, WARNING, "paper_generate_unavailable",
                      trace_id=trace_id, error=type(exc).__name__)
            return R(data=_degraded(req).model_dump())

        raw_ids = result.get("selectedIds") if isinstance(result, dict) else None
        if not isinstance(raw_ids, list) or not raw_ids:
            log_event(logger, WARNING, "paper_generate_invalid",
                      trace_id=trace_id, raw=str(result)[:200])
            return R(data=_degraded(req).model_dump())

        valid_ids: list[int] = []
        allowed = {c.id for c in req.candidates}
        for i in raw_ids:
            try:
                iid = int(i)
            except (TypeError, ValueError):
                continue
            if iid in allowed and iid not in valid_ids:
                valid_ids.append(iid)

        paper = PaperGenerateResult(
            paperTitle=str(result.get("paperTitle") or "").strip()
            or "个性化自测卷",
            selectedIds=valid_ids,
            rationale=str(result.get("rationale") or "").strip(),
            source="AI",
            status="SUCCESS",
        )
        log_event(logger, INFO, "paper_generate_done",
                  trace_id=trace_id, student_id=req.studentId, picked=len(valid_ids))
        return R(data=paper.model_dump())
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "paper_generate_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e)[:200])
        return R(data=_degraded(req).model_dump())
    finally:
        reset_context()
