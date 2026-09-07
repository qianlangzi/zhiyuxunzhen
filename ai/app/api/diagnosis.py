"""薄弱点学情诊断（P0-3）— 学情诊断 Agent

POST /internal/diagnosis/weakness
输入统计薄弱点（STAT：knowledgeTag / weaknessScore / evidenceCount）+ 近期错题，
LLM 输出「整体诊断 + 逐薄弱点 AI 归因」。
由业务中台调用，与统计分数合并后（source: STAT + AI）供推荐页展示。
AI 不可用时返回 status=DEGRADED 降级数据（不抛错），调用方回退纯统计。
"""
import uuid
from typing import Any

from fastapi import APIRouter, Depends
from logging import INFO, WARNING

from app.core.logging import ensure_trace_id, get_logger, log_event, set_context, reset_context
from app.core.security import require_internal_token
from app.models.common import R
from app.models.review import (
    WeaknessDiagnosisItem,
    WeaknessDiagnosisRequest,
    WeaknessDiagnosisResult,
)
from app.prompts.templates import weakness_diagnosis_prompt
from app.services.llm_client import llm_client

logger = get_logger(__name__)
router = APIRouter()


def _to_user_msg(req: WeaknessDiagnosisRequest) -> str:
    lines = [f"学生 ID：{req.studentId}"]
    if req.weaknesses:
        lines.append("统计薄弱知识点（掌握度越低越薄弱）：")
        for w in req.weaknesses[:10]:
            score = w.weaknessScore if w.weaknessScore is not None else "未知"
            cnt = w.evidenceCount if w.evidenceCount is not None else 0
            lines.append(f"- {w.knowledgeTag}（掌握度 {score}，证据 {cnt} 条）")
    if req.mistakes:
        lines.append("近期错题要点：")
        for m in req.mistakes[:12]:
            lines.append(f"- [{m.knowledgeTag}] {m.note[:80]}")
    if not req.weaknesses:
        lines.append("（无统计薄弱数据，仅基于错题推断）")
    lines.append("请输出整体学情诊断与逐薄弱点 AI 归因 JSON。")
    return "\n".join(lines)


@router.post("/internal/diagnosis/weakness", response_model=R)
async def diagnose_weakness(
    req: WeaknessDiagnosisRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        messages = [
            {"role": "system", "content": weakness_diagnosis_prompt()},
            {"role": "user", "content": _to_user_msg(req)},
        ]
        try:
            result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            log_event(logger, WARNING, "weakness_diagnosis_unavailable",
                      trace_id=trace_id, error=type(exc).__name__)
            return R(data=WeaknessDiagnosisResult(
                overall="AI 学情诊断服务暂时不可用，当前展示统计薄弱点。",
                items=[], source="RULE", status="DEGRADED").model_dump())

        if not isinstance(result, dict):
            log_event(logger, WARNING, "weakness_diagnosis_invalid",
                      trace_id=trace_id, raw=str(result)[:200])
            return R(data=WeaknessDiagnosisResult(
                overall="", items=[], source="RULE", status="DEGRADED").model_dump())

        # 防幻觉：只保留输入中真实存在的薄弱点
        allowed = {w.knowledgeTag for w in req.weaknesses}
        items: list[WeaknessDiagnosisItem] = []
        raw_items = result.get("items")
        if isinstance(raw_items, list):
            for it in raw_items:
                if not isinstance(it, dict):
                    continue
                tag = str(it.get("knowledgeTag") or "").strip()
                if not tag or (allowed and tag not in allowed):
                    continue
                items.append(WeaknessDiagnosisItem(
                    knowledgeTag=tag,
                    rootCause=str(it.get("rootCause") or ""),
                    suggestion=str(it.get("suggestion") or ""),
                ))
        # 未覆盖的薄弱点补一个空归因，保证前端可展示
        covered = {it.knowledgeTag for it in items}
        for w in req.weaknesses:
            if w.knowledgeTag not in covered:
                items.append(WeaknessDiagnosisItem(knowledgeTag=w.knowledgeTag))

        result_obj = WeaknessDiagnosisResult(
            overall=str(result.get("overall") or ""),
            items=items,
            source="AI",
            status="SUCCESS",
        )
        log_event(logger, INFO, "weakness_diagnosis_done",
                  trace_id=trace_id, student_id=req.studentId, items=len(items))
        return R(data=result_obj.model_dump())
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "weakness_diagnosis_failed",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e)[:200])
        return R(data=WeaknessDiagnosisResult(
            overall="", items=[], source="RULE", status="DEGRADED").model_dump())
    finally:
        reset_context()
