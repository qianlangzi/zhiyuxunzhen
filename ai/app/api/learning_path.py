"""个性化补救路径生成（PRD 9.3）— 学习教练 Agent

POST /learning_path/generate
由业务中台组装学生事实快照（薄弱知识点/错题要点/候选教材/题/病例），
学习教练 Agent 基于真实事实生成「知识水平诊断 + 递进学习路径」，
并通过 RAG 补充教材溯源。无事实快照时降级为通用路径（不阻断）。
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


def _facts_to_user_msg(req: LearningPathRequest) -> str:
    """把事实快照组装成给 LLM 的用户消息（无事实时回退通用提示）"""
    facts = req.facts
    if facts is None:
        return (
            f"学生 ID：{req.studentId}\n"
            "当前未获取到该学生的历史学习数据，请基于内科教学常见薄弱点，"
            "生成一份通用补救路径。若 RAG 提供教材溯源，必须包含书名与章节。"
        )
    lines = [f"学生 ID：{req.studentId}"]
    if facts.weaknesses:
        lines.append("薄弱知识点（掌握度越低越薄弱）：")
        for w in facts.weaknesses[:6]:
            score = w.weaknessScore if w.weaknessScore is not None else "未知"
            cnt = w.evidenceCount if w.evidenceCount is not None else 0
            lines.append(f"- {w.knowledgeTag}（掌握度 {score}，证据 {cnt} 条）")
    if facts.mistakes:
        lines.append("近期错题要点：")
        for m in facts.mistakes[:10]:
            lines.append(f"- [{m.knowledgeTag}] {m.note[:80]}")
    if facts.learnedChapters:
        lines.append("已学内容：" + "、".join(facts.learnedChapters[:8]))
    lines.append("候选教材（推荐只从中选择）：" +
                 ("、".join(f"{t.id}:{t.title}" for t in facts.candidateTextbooks) or "暂无"))
    lines.append("候选基础题（推荐只从中选择）：" +
                 ("、".join(f"{q.id}:{q.title}" for q in facts.candidateQuestions) or "暂无"))
    lines.append("候选病例（推荐只从中选择）：" +
                 ("、".join(f"{c.id}:{c.title}" for c in facts.candidateCases) or "暂无"))
    lines.append("请给出：1) 基于真实事实的知识水平诊断；2) 递进学习路径（知识点诊断→教材复习→简单病例→标准病例→综合病例），"
                 "每步给出 goal/detail/evidence/targetMetric/resources；3) 推荐的病例 id。")
    return "\n".join(lines)


def _extract_cases(result: dict[str, Any], req: LearningPathRequest) -> list[int]:
    """从候选病例中挑选推荐病例 id（防幻觉：只保留候选内的 id）"""
    raw = result.get("recommendedCases") or []
    if not isinstance(raw, list):
        return []
    allowed = {c.id for c in (req.facts.candidateCases if req.facts else [])}
    ids = [int(x) for x in raw if isinstance(x, (int, float, str)) and str(x).lstrip("-").isdigit()]
    if allowed:
        return [i for i in ids if i in allowed]
    return ids[:3]


@router.post("/learning_path/generate", response_model=R)
async def generate_learning_path(
    req: LearningPathRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        messages = [
            {"role": "system", "content": learning_path_prompt()},
            {"role": "user", "content": _facts_to_user_msg(req)},
        ]
        try:
            result: dict[str, Any] = await llm_client.chat_json(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        if not isinstance(result, dict) or ("pathSteps" not in result and "recommendedSteps" not in result):
            log_event(logger, WARNING, "learning_path_invalid",
                      trace_id=trace_id, raw=str(result)[:200])
            raise OutputSchemaInvalidError(trace_id=trace_id) from None

        # RAG 补充教材溯源
        query = "、".join(result.get("weakKnowledgeTags", [])[:3]) or "内科常见薄弱点"
        citations = await rag_service.search(query, top_k=3, trace_id=trace_id)

        path = LearningPathResult(
            studentId=req.studentId,
            diagnosis=result.get("diagnosis") or "",
            weakKnowledgeTags=result.get("weakKnowledgeTags", []),
            pathSteps=result.get("pathSteps", []),
            recommendedSteps=result.get("recommendedSteps", []),
            recommendedCases=_extract_cases(result, req),
            citations=[c.model_dump() for c in citations],
        )
        log_event(logger, INFO, "learning_path_done",
                  trace_id=trace_id, student_id=req.studentId,
                  steps=len(path.pathSteps) or len(path.recommendedSteps))
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
