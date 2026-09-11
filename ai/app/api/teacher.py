"""教师端 AI 辅助能力（PRD 9.3 扩展）

Spring Boot 调用，需 X-Internal-Token 鉴权。

提供 6 个能力：
1. /case/draft              AI 生成 SP 病例草稿（RAG 教材锚点）
2. /insight/class           AI 班级学情洞察（纯统计归纳，无 RAG）
3. /review/teacher_assist   AI 复核辅助（RAG 教材锚点）
4. /assignment/recommend    AI 推荐作业病例（病例库匹配，无教材 RAG）
5. /case/quality_check      AI 病例质检（RAG 教材锚点）
6. /case/practice_questions AI 自动生成练习题（RAG 教材锚点）

防幻觉原则：
- 涉及医学事实的生成（1/3/5/6）先 RAG 检索教材，LLM 基于教材原文生成，并强制溯源；
- 纯归纳（2）与资源匹配（4）不引入教材 RAG，LLM 只归纳/匹配输入中的真实数据；
- 所有输出经 structured_output 严格校验，安全策略在输出前拦截敏感内容。
"""
import json
import uuid
from logging import INFO, WARNING

from fastapi import APIRouter, Depends

from app.core.errors import (
    ApiError,
    ModelUnavailableError,
    OutputSchemaInvalidError,
    RetrievalUnavailableError,
)
from app.core.logging import ensure_trace_id, get_logger, log_event, reset_context, set_context
from app.core.security import require_internal_token
from app.domain.policies.safety_policy import safety_policy
from app.models.common import R
from app.models.teacher import (
    CaseDraftRequest,
    CaseDraftResult,
    ClassInsightRequest,
    ClassInsightResult,
    MaterialAdviceRequest,
    MaterialAdviceResult,
    PracticeQuestionsRequest,
    PracticeQuestionsResult,
    QualityRequest,
    QualityResult,
    RecommendCasesRequest,
    RecommendCasesResult,
    ReviewAssistRequest,
    ReviewAssistResult,
)
from app.prompts.templates import (
    case_draft_prompt,
    class_insight_prompt,
    material_advice_prompt,
    practice_questions_prompt,
    quality_check_prompt,
    recommend_cases_prompt,
    review_assist_prompt,
)
from app.services.llm_client import llm_client
from app.services.rag_service import rag_service
from app.services.structured_output import structured_output

logger = get_logger(__name__)
router = APIRouter()


def _build_rag_context(citations) -> str:
    """把 RAG 检索结果拼成可供 LLM 引用的教材上下文；无结果时明确告知 LLM 不得虚构。"""
    if not citations:
        return "（未检索到教材依据：生成医学事实时必须标注“待补充”，禁止编造）"
    lines = []
    for c in citations:
        page = c.page_number or ""
        chapter = c.chapter or ""
        lines.append(
            f"- 《{c.book_name}》{'·' + chapter if chapter else ''}"
            f"{'·P' + str(page) if page else ''}：{c.chunk_text or ''}"
        )
    return "\n".join(lines)


# ---------- 1. AI 生成 SP 病例草稿 ----------

@router.post("/case/draft", response_model=R)
async def generate_case_draft(
    req: CaseDraftRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # 未配置大模型时直接给出可操作提示（避免降级文案被当作 JSON 解析后报 schema 错，
        # 进而被误报为"AI 暂不可用"）
        if not llm_client.available:
            log_event(logger, WARNING, "case_draft_llm_not_configured", trace_id=trace_id)
            return R(
                code=503,
                message="大模型未配置：请在 .env 中填写 LLM_BASE_URL / LLM_API_KEY 后重启 AI 服务",
                data=None,
            )

        # RAG：以教学目标+主诉+科室检索教材，作为 LLM 事实锚点（防幻觉）
        query = "、".join(req.teachingGoals) or req.chiefComplaint
        try:
            citations = await rag_service.search(f"{req.department} {query}", top_k=5, trace_id=trace_id)
        except RetrievalUnavailableError:
            citations = []
            log_event(logger, WARNING, "case_draft_rag_unavailable", trace_id=trace_id)

        user_msg = (
            f"科室：{req.department}\n"
            f"主诉：{req.chiefComplaint}\n"
            f"难度：{'简单' if req.difficulty == 1 else '标准' if req.difficulty == 2 else '困难'}\n"
            f"教学目标：{'、'.join(req.teachingGoals) or '未指定'}\n"
            + (f"教师补充说明：{req.remark}\n" if req.remark else "")
            + "\n"
            f"教材参考（仅可依据此生成，禁止虚构）：\n{_build_rag_context(citations)}\n\n"
            "请按 schema 输出病例草稿 JSON。"
        )
        messages = [
            {"role": "system", "content": case_draft_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, disable_thinking=True, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        # 结构化校验（extra 字段拒收）
        result: CaseDraftResult = await structured_output.parse_and_validate(
            raw, CaseDraftResult, trace_id=trace_id,
        )
        # 若 RAG 可用，把实际命中的教材溯源合并进 citations（保证可追溯）
        if citations:
            existing = {f"{c.book_name}:{c.page_number}" for c in result.citations}
            for c in citations:
                key = f"{c.book_name}:{c.page_number}"
                if key not in existing:
                    result.citations.append(c)
                    existing.add(key)

        # 输出安全策略：拦截隐藏疾病/敏感内容异常
        safety = safety_policy.check_output(json.dumps(result.model_dump(), ensure_ascii=False))
        if safety.is_blocked:
            log_event(logger, WARNING, "case_draft_safety_blocked", trace_id=trace_id, reason=safety.reason)
            raise OutputSchemaInvalidError("生成结果未通过安全校验，请调整输入后重试", trace_id)

        log_event(logger, INFO, "case_draft_done", trace_id=trace_id,
                  complaint=req.chiefComplaint, citations=len(result.citations))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "case_draft_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "case_draft_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"病例草稿生成失败：{e}", data=None)
    finally:
        reset_context()


# ---------- 2. AI 班级学情洞察 ----------

@router.post("/insight/class", response_model=R)
async def class_insight(
    req: ClassInsightRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        stats_text = "\n".join(f"- {s.label}: {s.value}" for s in req.stats) or "（暂无统计）"
        osce_text = "\n".join(f"- {k}: {v}" for k, v in req.osceDimensionScores.items()) or "（暂无 OSCE 维度数据）"
        mistakes_text = "\n".join(f"- {m.type}: {m.description}（{m.count}次）" for m in req.commonMistakes) or "（暂无错题数据）"

        user_msg = (
            f"班级：{req.className or '未命名'}\n"
            f"核心统计：\n{stats_text}\n\n"
            f"OSCE 维度均分：\n{osce_text}\n\n"
            f"共性错题：\n{mistakes_text}\n\n"
            "请严格基于以上数据输出学情洞察 JSON，禁止新增任何未给出的数字。"
        )
        messages = [
            {"role": "system", "content": class_insight_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, disable_thinking=True, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: ClassInsightResult = await structured_output.parse_and_validate(
            raw, ClassInsightResult, trace_id=trace_id,
        )
        log_event(logger, INFO, "class_insight_done", trace_id=trace_id,
                  suggestions=len(result.teachingSuggestions))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "class_insight_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "class_insight_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"学情洞察生成失败：{e}", data=None)
    finally:
        reset_context()


# ---------- 3. AI 复核辅助 ----------

@router.post("/review/teacher_assist", response_model=R)
async def review_assist(
    req: ReviewAssistRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # RAG：用批阅中的扣分点/诊断关键词检索教材，作为复核依据（防幻觉）
        diagnosis_kw = "、".join(
            m.get("comment", "")[:20] for m in req.aiMistakes if m.get("comment")
        ) or req.caseContext[:30]
        try:
            citations = await rag_service.search(diagnosis_kw, top_k=3, trace_id=trace_id)
        except RetrievalUnavailableError:
            citations = []

        ai_mistakes_text = json.dumps(req.aiMistakes, ensure_ascii=False)
        user_msg = (
            f"学生大病历：\n{req.medicalRecordText}\n\n"
            f"病例标准路径：\n{req.caseContext or '未提供'}\n\n"
            f"AI 批阅得分：{req.aiScore}\n"
            f"AI 批阅错误项：\n{ai_mistakes_text}\n\n"
            f"教材参考（仅可依据此引用）：\n{_build_rag_context(citations)}\n\n"
            "请逐条复核 AI 批阅项，输出复核建议 JSON。"
        )
        messages = [
            {"role": "system", "content": review_assist_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, disable_thinking=True, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: ReviewAssistResult = await structured_output.parse_and_validate(
            raw, ReviewAssistResult, trace_id=trace_id,
        )
        log_event(logger, INFO, "review_assist_done", trace_id=trace_id,
                  instance_id=req.instanceId, suggestions=len(result.suggestions))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "review_assist_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "review_assist_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"复核建议生成失败：{e}", data=None)
    finally:
        reset_context()


# ---------- 4. AI 推荐作业病例 ----------

@router.post("/assignment/recommend", response_model=R)
async def recommend_cases(
    req: RecommendCasesRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        if not req.candidateCases:
            return R(data=RecommendCasesResult().model_dump())

        weaknesses_text = "\n".join(
            f"- {w.tag}（薄弱度 {w.score:.2f}）" for w in req.weaknesses
        ) or "（暂无班级薄弱点数据）"
        cases_text = "\n".join(
            f"- caseId={c.caseId} |《{c.title}》| 难度{['','简单','标准','困难'][c.difficulty] if 1 <= c.difficulty <= 3 else c.difficulty} | 标签:{'、'.join(c.knowledgeTags)}"
            for c in req.candidateCases
        )

        user_msg = (
            f"班级薄弱知识点：\n{weaknesses_text}\n\n"
            f"候选病例库：\n{cases_text}\n\n"
            "请从候选病例中推荐 3-5 个最适合本次作业的病例，输出推荐 JSON。"
        )
        messages = [
            {"role": "system", "content": recommend_cases_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, disable_thinking=True, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: RecommendCasesResult = await structured_output.parse_and_validate(
            raw, RecommendCasesResult, trace_id=trace_id,
        )
        # 防幻觉兜底：剔除推荐了不存在 caseId 的结果
        valid_ids = {c.caseId for c in req.candidateCases}
        result.recommendations = [r for r in result.recommendations if r.caseId in valid_ids]
        log_event(logger, INFO, "recommend_cases_done", trace_id=trace_id,
                  class_id=req.classId, recommended=len(result.recommendations))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "recommend_cases_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "recommend_cases_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"病例推荐失败：{e}", data=None)
    finally:
        reset_context()


# ---------- 5. AI 病例质检 ----------

@router.post("/case/quality_check", response_model=R)
async def quality_check(
    req: QualityRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # RAG：以隐藏疾病检索教材，作为质检依据
        try:
            citations = await rag_service.search(req.hiddenDisease, top_k=5, trace_id=trace_id)
        except RetrievalUnavailableError:
            citations = []

        user_msg = (
            f"病例标题：{req.title}\n"
            f"隐藏疾病：{req.hiddenDisease}\n"
            f"标准路径：\n{chr(10).join('- ' + s for s in req.standardPath) or '未提供'}\n"
            f"预设检查：\n{json.dumps(req.presetExams, ensure_ascii=False)}\n"
            f"知识点标签：{'、'.join(req.knowledgeTags) or '未提供'}\n\n"
            f"教材参考（仅可依据此判断）：\n{_build_rag_context(citations)}\n\n"
            "请输出病例质检 JSON。"
        )
        messages = [
            {"role": "system", "content": quality_check_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, disable_thinking=True, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: QualityResult = await structured_output.parse_and_validate(
            raw, QualityResult, trace_id=trace_id,
        )
        log_event(logger, INFO, "quality_check_done", trace_id=trace_id,
                  case_id=req.caseId, overall=result.overallPass)
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "quality_check_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "quality_check_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"病例质检失败：{e}", data=None)
    finally:
        reset_context()


# ---------- 6. AI 自动生成练习题 ----------

@router.post("/case/practice_questions", response_model=R)
async def practice_questions(
    req: PracticeQuestionsRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        # RAG：以知识点+隐藏疾病检索教材，作为出题事实锚点
        query = "、".join(req.knowledgeTags) or req.hiddenDisease
        try:
            citations = await rag_service.search(query, top_k=5, trace_id=trace_id)
        except RetrievalUnavailableError:
            citations = []

        user_msg = (
            f"隐藏疾病：{req.hiddenDisease}\n"
            f"标准路径：\n{chr(10).join('- ' + s for s in req.standardPath) or '未提供'}\n"
            f"知识点标签：{'、'.join(req.knowledgeTags) or '未提供'}\n\n"
            f"教材参考（仅可依据此生成题目）：\n{_build_rag_context(citations)}\n\n"
            "请生成 3-5 道配套练习题 JSON。"
        )
        messages = [
            {"role": "system", "content": practice_questions_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, disable_thinking=True, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: PracticeQuestionsResult = await structured_output.parse_and_validate(
            raw, PracticeQuestionsResult, trace_id=trace_id,
        )
        log_event(logger, INFO, "practice_questions_done", trace_id=trace_id,
                  case_id=req.caseId, questions=len(result.questions))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "practice_questions_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "practice_questions_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"练习题生成失败：{e}", data=None)
    finally:
        reset_context()

# ---------- 7. 病例素材智能推荐 ----------

@router.post("/case/material_advice", response_model=R)
async def material_advice(
    req: MaterialAdviceRequest,
    _token: None = Depends(require_internal_token),
):
    """教师构建病例时，AI 推荐应准备的多模态材料清单（X光/CT/心电图/报告单等）。

    纯归纳型能力：只基于病例自身信息推荐，不引入教材 RAG，杜绝编造检查依据。
    """
    trace_id = ensure_trace_id()
    set_context(trace_id=trace_id)
    try:
        existing = "、".join(req.existingExams) if req.existingExams else "（暂无）"
        messages = [
            {"role": "system", "content": material_advice_prompt(
                title=req.title, department=req.department, complaint=req.complaint,
                hidden_disease=req.hiddenDisease, present_illness=req.presentIllness,
                existing=existing,
            )},
            {"role": "user", "content": "请按 schema 输出素材建议 JSON。"},
        ]
        raw = await llm_client.chat(messages, disable_thinking=True, trace_id=trace_id)
        result: MaterialAdviceResult = await structured_output.parse_and_validate(
            raw, MaterialAdviceResult, trace_id=trace_id,
        )
        log_event(logger, INFO, "material_advice_done", trace_id=trace_id,
                  case_id=req.caseId, suggestions=len(result.suggestions))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "material_advice_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "material_advice_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"素材推荐失败：{e}", data=None)
    finally:
        reset_context()
