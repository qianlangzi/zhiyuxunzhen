"""每日病历（大病历训练闭环）AI 接口

POST /mr/segment_hint    段落教练：三级提示梯度（追问→定向提示→示范片段），绝不代写
POST /mr/review_record   结构化批阅：九段独立评分 + 缺陷标签打标 + 置信度

两个接口均由业务中台经 /internal/agent/evaluator 网关以 action=mr_hint / mr_review 调用
（见 agents/gateway_features.py），也保留直连路由（X-Internal-Token 鉴权）便于联调。
"""
import json
from logging import INFO, WARNING

from fastapi import APIRouter, Depends

from app.core.errors import ApiError, OutputSchemaInvalidError
from app.core.logging import ensure_trace_id, get_logger, log_event, reset_context, set_context
from app.core.security import require_internal_token
from app.models.common import R
from app.models.mr import (
    MrReviewRequest,
    MrReviewResult,
    MrSegmentHintRequest,
    MrSegmentHintResult,
)
from app.prompts.templates import mr_coach_prompt, mr_reviewer_prompt
from app.services.llm_client import LlmFallbackError, llm_client
from app.services.rag_service import rag_service

logger = get_logger(__name__)
router = APIRouter()

# 与 V43 迁移 mr_defect_tag 字典一致；Java 可通过请求体 defectTags 覆盖
BUILTIN_DEFECT_TAGS = (
    "CC_TOO_LONG 主诉超过20字 | CC_HAS_DIAGNOSIS 主诉含诊断性词语 | CC_NO_DURATION 主诉缺时限 | "
    "HPI_NO_ONSET 现病史缺起病情况 | HPI_NO_COURSE 现病史缺病情演变 | HPI_NO_CAUSE 现病史缺诱因 | "
    "HPI_NO_RELIEF 缓解/加重因素缺失 | HPI_NO_GENERAL 缺一般情况 | HPI_TIMELINE_CHAOS 现病史时序混乱 | "
    "PMH_MISSING 既往史缺失 | PMH_NO_FILTER 既往史未筛选相关性 | "
    "PE_NO_VITALS 查体缺生命体征 | PE_NO_POSITIVE 缺阳性体征 | PE_NO_NEGATIVE 缺鉴别意义阴性体征 | PE_DISORDER 查体顺序混乱 | "
    "AE_MISSING 辅助检查缺失 | AE_IRRATIONAL 检查选择不合理 | "
    "DX_INCOMPLETE 初步诊断不完整 | DX_ORDER 诊断主次顺序不当 | "
    "BASIS_INSUFFICIENT 诊断依据不充分 | BASIS_NO_QUOTE 依据未引用病历内容 | "
    "DDX_INSUFFICIENT 鉴别诊断不足2个 | DDX_NO_SUPPORT 鉴别无支持点 | DDX_NO_EXCLUDE 鉴别无排除点 | "
    "PLAN_GENERIC 诊疗计划泛化 | PLAN_NO_FOLLOWUP 诊疗计划缺随访 | "
    "TERM_ERROR 医学术语使用错误 | LOGIC_CONFLICT 内容前后矛盾"
)

SEGMENT_FULL_SCORES = {
    "chief_complaint": 8, "history_present": 25, "history_past": 10,
    "physical_exam": 15, "auxiliary_exam": 7, "diagnosis": 8,
    "diagnosis_basis": 10, "differential": 12, "treatment_plan": 5,
}


@router.post("/mr/segment_hint", response_model=R)
async def segment_hint(
    req: MrSegmentHintRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        level = max(1, min(3, int(req.hintLevel or 1)))
        materials = "\n".join(f"- {m}" for m in req.materials[:10]) if req.materials else "（无）"
        messages = [
            {"role": "system", "content": mr_coach_prompt(
                segment_name=req.segmentName or req.segmentKey,
                segment_spec=req.segmentSpec or "按大病历通用规范书写",
                case_summary=req.caseSummary,
                key_findings=req.keyFindings,
                draft=req.draft,
                materials=materials,
                hint_level=level,
            )},
            {"role": "user", "content": f"当前提示等级 hintLevel={level}。请按 schema 输出引导 JSON。"},
        ]
        result = await llm_client.chat_json(messages, trace_id=trace_id)
        if not isinstance(result, dict) or not result.get("text"):
            log_event(logger, WARNING, "mr_hint_invalid", trace_id=trace_id)
            raise OutputSchemaInvalidError(trace_id=trace_id) from None
        hint = MrSegmentHintResult(
            type=str(result.get("type") or ("question" if level == 1 else "hint")),
            text=str(result.get("text") or ""),
            quoteMaterials=[str(m) for m in (result.get("quoteMaterials") or [])][:3],
        )
        log_event(logger, INFO, "mr_hint_done", trace_id=trace_id,
                  schedule_id=req.scheduleId, hint_level=level, hint_type=hint.type)
        return R(data=hint.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "mr_hint_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "mr_hint_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"段落教练失败：{e}", data=None)
    finally:
        reset_context()


@router.post("/mr/review_record", response_model=R)
async def review_record(
    req: MrReviewRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # 教材 RAG 锚点（可选增强，失败静默降级，与 essay_review 同策略）
        rag_text = ""
        try:
            citations = await rag_service.search(req.caseContext[:200] or "内科学 大病历书写", top_k=3,
                                                 trace_id=trace_id)
            rag_text = "\n".join(
                f"- 《{c.book_name}》·{c.chapter or ''}·P{c.page_number or ''}：{(c.chunk_text or '')[:200]}"
                for c in citations
            )
        except Exception:  # noqa: BLE001
            log_event(logger, WARNING, "mr_review_rag_unavailable", trace_id=trace_id)

        record_text = json.dumps(req.record, ensure_ascii=False)
        messages = [
            {"role": "system", "content": mr_reviewer_prompt(
                case_context=(req.caseContext or "") + (f"\n教材参考：\n{rag_text}" if rag_text else ""),
                standard_answer=req.standardAnswer,
                defect_tags=req.defectTags or BUILTIN_DEFECT_TAGS,
                record=record_text,
            )},
            {"role": "user", "content": "请按 schema 输出结构化批阅 JSON。"},
        ]
        result = await llm_client.chat_json(messages, trace_id=trace_id)
        if not isinstance(result, dict) or "totalScore" not in result:
            log_event(logger, WARNING, "mr_review_invalid", trace_id=trace_id)
            raise OutputSchemaInvalidError(trace_id=trace_id) from None

        total = max(0.0, min(100.0, float(result["totalScore"])))
        segments_raw = result.get("segments") or []
        segments = []
        for seg in segments_raw:
            if not isinstance(seg, dict) or "key" not in seg:
                continue
            key = str(seg["key"])
            full = float(seg.get("full") or SEGMENT_FULL_SCORES.get(key, 0))
            score = max(0.0, min(full, float(seg.get("score") or 0)))
            defects = [d for d in (seg.get("defects") or []) if isinstance(d, dict) and d.get("tag")]
            segments.append({
                "key": key, "score": round(score, 1), "full": full,
                "comment": str(seg.get("comment") or ""),
                "defects": [{
                    "tag": str(d["tag"]),
                    "level": max(1, min(3, int(d.get("level") or 1))),
                    "msg": str(d.get("msg") or ""),
                    "suggest": str(d.get("suggest") or ""),
                } for d in defects],
            })
        tags = [str(t) for t in (result.get("defectTags") or []) if t]
        # 兜底：若 LLM 漏给 defectTags，从段级缺陷聚合
        if not tags:
            tags = list({d["tag"] for s in segments for d in s["defects"]})
        try:
            confidence = max(0.0, min(1.0, float(result.get("confidence") or 0.0)))
        except (TypeError, ValueError):
            confidence = 0.0

        review = MrReviewResult(
            totalScore=round(total, 1),
            confidence=confidence,
            segments=segments,
            defectTags=tags,
            reviewComment=str(result.get("reviewComment") or ""),
        )
        log_event(logger, INFO, "mr_review_done", trace_id=trace_id,
                  schedule_id=req.scheduleId, score=review.totalScore,
                  confidence=review.confidence, defects=len(tags))
        return R(data=review.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "mr_review_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except LlmFallbackError as exc:
        log_event(logger, WARNING, "mr_review_model_unavailable", trace_id=trace_id)
        return R(code=503, message="AI 模型暂不可用，请稍后重试", data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "mr_review_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"批阅失败：{e}", data=None)
    finally:
        reset_context()
