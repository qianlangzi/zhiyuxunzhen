"""智能备课：AI 教学设计生成与对话式引导接口（助教核心）

POST /lesson/design
- 输入：课程主题/教学目标/关联病例/教材锚点/学情数据/课时
- RAG 检索教材（以疾病/知识点为锚点），LLM 基于教材与学情生成医学教案
- 输出经 structured_output 严格校验 + safety 检查

POST /lesson/guide
- 向导式对话引导：输入已确认要素 + 用户最新回答，输出下一个问题/快捷选项/是否完成/需求单
"""
import json
import uuid
from logging import INFO, WARNING
from urllib.parse import urlparse

from fastapi import APIRouter, Depends
from openai import AsyncOpenAI

from app.core.config import settings
from app.core.errors import ApiError, ModelUnavailableError, OutputSchemaInvalidError, RetrievalUnavailableError
from app.core.logging import get_logger, log_event, reset_context, set_context
from app.core.security import require_internal_token
from app.domain.policies.safety_policy import safety_policy
from app.models.common import R
from app.models.lesson import LessonDesignRef, LessonDesignRequest, LessonDesignResult, LessonGuideRequest, LessonGuideResult, LessonMergeRequest, LessonPptRequest, LessonPptResult
from app.prompts.templates import lesson_design_prompt, lesson_guide_prompt, lesson_merge_prompt, lesson_ppt_prompt
from app.services.llm_client import llm_client
from app.services.rag_service import rag_service
from app.services.structured_output import structured_output

logger = get_logger(__name__)
router = APIRouter()


async def _describe_material_image(file_url: str, trace_id: str) -> str:
    """用 VLM 识别备课包上传的图片素材，返回一段结构化文字描述。

    仅在已配置多模态模型、且图片为公网 HTTP(S) URL 时执行；任何失败都优雅降级
    为该图片仅以标题作锚点，避免阻断教案生成。
    """
    if not settings.vision_configured or not file_url:
        return ""
    parsed = urlparse(file_url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return ""
    try:
        client = AsyncOpenAI(
            base_url=settings.vision_base_url,
            api_key=settings.vision_api_key.get_secret_value(),
            timeout=60.0,
        )
        resp = await client.chat.completions.create(
            model=settings.vision_model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "你是医学教学素材转写助手。请用简洁的中文，描述这张图片用于备课的核心内容："
                        "图上展示什么（解剖图/病理切片/影像/检查报告/表格/流程图等）、关键医学信息、"
                        "以及它适合放入教案的哪个环节（导入/讲授/病例讨论/技能训练）。只输出描述正文，不要客套。"
                    ),
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "请转写这张医学教学图片。"},
                        {"type": "image_url", "image_url": {"url": file_url}},
                    ],
                },
            ],
            max_tokens=500,
        )
        desc = (resp.choices[0].message.content or "").strip()
        log_event(logger, INFO, "lesson_material_vision_ok", trace_id=trace_id,
                  length=len(desc))
        return desc
    except Exception as exc:  # noqa: BLE001
        log_event(logger, WARNING, "lesson_material_vision_unavailable",
                  trace_id=trace_id, error=type(exc).__name__, msg=str(exc)[:200])
        return ""


@router.post("/lesson/design", response_model=R)
async def lesson_design(
    req: LessonDesignRequest,
    _token: None = Depends(require_internal_token),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        # RAG：以课程主题/知识点检索教材，作为教学设计的事实锚点
        query = "、".join(req.teachingGoals) or req.title
        citations = []
        try:
            citations = await rag_service.search(
                f"{req.department} {query}".strip(), top_k=5, trace_id=trace_id,
            )
        except RetrievalUnavailableError:
            log_event(logger, WARNING, "lesson_design_rag_unavailable", trace_id=trace_id)

        refs_text = "\n".join(
            f"- 《{c.get('book_name')}》·{c.get('chapter') or ''}·P{c.get('page_number') or ''}"
            for c in (req.textbookRefs or []) if c.get("book_name")
        ) or "（无外部锚点）"

        # 备课包多模态素材：图片走 VLM 识别为可用上下文；pdf/ppt 以标题作教材锚点
        materials_text = ""
        if req.materialRefs:
            material_lines = []
            for m in req.materialRefs:
                title = str(m.get("title") or "未命名素材")
                mtype = str(m.get("materialType") or "").lower()
                if mtype in {"image", "png", "jpg", "jpeg"} and m.get("fileUrl"):
                    desc = await _describe_material_image(str(m.get("fileUrl")), trace_id)
                    if desc:
                        material_lines.append(f"- 图片《{title}》：{desc}")
                    else:
                        material_lines.append(f"- 图片《{title}》（VLM 未配置或不可用，仅以标题锚点，教学内容须标注待补充）")
                else:
                    material_lines.append(f"- 课件《{title}》（{mtype}，作为教学参考锚点）")
            if material_lines:
                materials_text = "\n".join(material_lines)

        rag_text = "\n".join(
            f"- 《{c.book_name}》·{c.chapter or ''}·P{c.page_number or ''}：{(c.chunk_text or '')[:300]}"
            for c in citations
        ) or "（未检索到教材内容，涉及出处须标注待补充）"

        student_text = req.studentProfile or "（未指定学情，禁止编造学生情况，studentProfileNote 标注建议补充）"

        user_msg = (
            f"课程主题：{req.title}\n"
            f"科室/疾病系统：{req.department or '未指定'}\n"
            f"适用年级：{req.targetGrade or '未指定'}\n"
            f"课时时长：{req.lessonDuration or 45} 分钟\n"
            f"教学目标：{'、'.join(req.teachingGoals) or '未指定'}\n"
            f"关联病例：{req.caseContext or '无'}\n\n"
            f"学情数据（真实系统数据，仅可引用其中内容）：\n{student_text}\n\n"
            f"教材参考（仅可依据此生成，禁止虚构）：\n{rag_text}\n\n"
            f"外部教材锚点（教师提供）：\n{refs_text}\n\n"
            f"教师上传的多模态素材（图片为 VLM 转写内容，课件作参考锚点；只能作为教学内容补充，不能替代教材出处）：\n{materials_text}\n\n"
            "请按 schema 输出医学教案 JSON。"
        )
        messages = [
            {"role": "system", "content": lesson_design_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: LessonDesignResult = await structured_output.parse_and_validate(
            raw, LessonDesignResult, trace_id=trace_id,
        )
        # 合并实际命中的教材溯源
        if citations:
            existing = {f"{c.book_name}:{c.page_number}" for c in result.textbookRefs}
            for c in citations:
                key = f"{c.book_name}:{c.page_number}"
                if key not in existing:
                    result.textbookRefs.append(
                        LessonDesignRef(
                            book_name=c.book_name, chapter=c.chapter, page_number=c.page_number,
                        )
                    )
                    existing.add(key)

        safety = safety_policy.check_output(json.dumps(result.model_dump(), ensure_ascii=False))
        if safety.is_blocked:
            raise OutputSchemaInvalidError("生成结果未通过安全校验，请调整输入后重试", trace_id)

        log_event(logger, INFO, "lesson_design_done", trace_id=trace_id,
                  title=req.title, citations=len(result.textbookRefs))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "lesson_design_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "lesson_design_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"教学设计生成失败：{e}", data=None)
    finally:
        reset_context()


@router.post("/lesson/guide", response_model=R)
async def lesson_guide(
    req: LessonGuideRequest,
    _token: None = Depends(require_internal_token),
):
    """向导式备课对话：确定性地逐要素推进（不依赖模型状态记忆）"""
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        # 要素顺序固定的确定性状态机：字段推进、完成判定、需求单汇总都由代码完成，
        # 模型仅负责为"当前待确认字段"生成一句中文提问与快捷选项（可选）。
        order = ["topic", "textbook", "classInfo", "duration", "emphasis", "extra"]
        labels = {
            "topic": "备课主题/主要内容",
            "textbook": "采用的教材（书名+章节）",
            "classInfo": "授课班级与学生学情（班级、基础、薄弱点；可选真实班级）",
            "duration": "课时安排（如 45分钟/90分钟）",
            "emphasis": "教学重难点偏好（可选，如易错点/常考考点）",
            "extra": "其他要求（可选，如侧重技能训练、准备SP问诊）",
        }
        confirmed = dict(req.confirmed or {})

        # 1) 把用户本轮回答并入"当前待确认字段"（当前字段 = 顺序上第一个尚未提供的键）
        reply = (req.userReply or "").strip()
        current = next((k for k in order if not str(confirmed.get(k) or "").strip()), None)

        done_keyword = any(w in reply for w in ("开始生成", "就这样", "完成", "生成教案"))
        if reply and not done_keyword and current:
            # 若用户答案明显命中下一个待确认字段（而非当前字段），优先归位
            hint_map = {
                "textbook": ["教材", "内科学", "外科学", "第"],
                "classInfo": ["班", "学情", "学生", "基础", "薄弱"],
                "duration": ["分钟", "课时", "45", "90"],
                "emphasis": ["重点", "难点", "易错", "考点"],
                "extra": ["技能", "SP", "问诊", "案例"],
            }
            for k, words in hint_map.items():
                if k != current and not str(confirmed.get(k) or "").strip() \
                        and any(w in reply for w in words):
                    confirmed[k] = reply
                    break
            else:
                confirmed[current] = reply
        elif done_keyword:
            # 用户要求开始生成：未确认项记「待补充」并完成
            for k in order:
                if not str(confirmed.get(k) or "").strip():
                    confirmed[k] = "待补充"

        # 2) 重新定位下一个待确认字段
        current = next((k for k in order if not str(confirmed.get(k) or "").strip()), None)
        complete = current is None

        result = LessonGuideResult(confirmed=confirmed, complete=complete)
        if complete:
            result.summary = dict(confirmed)
            log_event(logger, INFO, "lesson_guide_step", trace_id=trace_id,
                      step=req.step, complete=True, confirmed=list(confirmed))
            return R(data=result.model_dump())

        # 3) 未完成：让模型为当前字段生成一句自然中文提问与快捷选项
        result.field = current
        result.missing = [k for k in order if not str(confirmed.get(k) or "").strip()]
        # 是否允许多选：重难点偏好/其他要求这类可多要素并列的情境允许多选
        multi_select = current in ("emphasis", "extra")
        result.multiSelect = multi_select
        current_text = "\n".join(f"- {k}: {linked}" for k, linked in confirmed.items()
                                 if str(linked or "").strip()) or "（尚无）"
        user_msg = (
            f"当前已确认要素：\n{current_text}\n\n"
            f"接下来需要确认：{current}（{labels[current]}）\n\n"
            "请用一句简短自然的中文，针对上述字段向教师提问，并给出合适的快捷选项。"
        )
        messages = [
            {"role": "system", "content": lesson_guide_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            # 模型不可用时降级为确定性默认提问，不阻断引导流程
            result.question = f"请问这条备课的{labels[current]}是什么？"
            result.options = []
            result.optionsHint = "请直接回答或从下方选项选择"
            log_event(logger, WARNING, "lesson_guide_llm_unavailable", trace_id=trace_id)
            return R(data=result.model_dump())

        try:
            parsed: dict = await structured_output.parse_to_dict(raw, trace_id=trace_id)
        except Exception:  # noqa: BLE001
            parsed = {}
        result.question = str(parsed.get("question") or f"请问这条备课的{labels[current]}是什么？")
        result.options = [str(o) for o in parsed.get("options") or []]
        result.optionsHint = str(parsed.get("optionsHint") or "请直接回答或从下方选项选择")

        log_event(logger, INFO, "lesson_guide_step", trace_id=trace_id,
                  step=req.step, complete=False, field=result.field)
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "lesson_guide_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "lesson_guide_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"备课引导失败：{e}", data=None)
    finally:
        reset_context()


@router.post("/lesson/merge", response_model=R)
async def lesson_merge(
    req: LessonMergeRequest,
    _token: None = Depends(require_internal_token),
):
    """AI 合并多份教案：以优先级最高教案为主体，用 LLM 消解各方冲突，
    产出单一连贯的医学教案（LessonDesignResult）。"""
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        if not req.designs or len(req.designs) < 2:
            raise ApiError("INVALID_INPUT", "合并至少需要 2 份教案", 400, trace_id)
        blocks = [f"教案 {i}（优先级：{'高' if i == 1 else i}）："
                  f"\n{json.dumps(d, ensure_ascii=False)}"
                  for i, d in enumerate(req.designs, 1)]
        designs_text = "\n\n".join(blocks)
        user_msg = (
            f"合并后标题:{req.title or '（沿用优先级最高教案标题）'}\n"
            f"科室/疾病系统:{req.department or '未指定'}\n"
            f"适用年级:{req.targetGrade or '未指定'}\n"
            f"课时时长:{req.lessonDuration or 45} 分钟\n\n"
            f"以下为 {len(req.designs)} 份待合并教案的设计结果（按优先级从高到低排列）:\n\n"
            f"{designs_text}\n\n"
            "请输出合并后单份医学教案的 JSON。"
        )
        messages = [
            {"role": "system", "content": lesson_merge_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: LessonDesignResult = await structured_output.parse_and_validate(
            raw, LessonDesignResult, trace_id=trace_id,
        )
        safety = safety_policy.check_output(json.dumps(result.model_dump(), ensure_ascii=False))
        if safety.is_blocked:
            raise OutputSchemaInvalidError("合并结果未通过安全校验，请调整后重试", trace_id)

        log_event(logger, INFO, "lesson_merge_done", trace_id=trace_id,
                  title=req.title, count=len(req.designs))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "lesson_merge_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "lesson_merge_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"教案合并失败:{e}", data=None)
    finally:
        reset_context()


@router.post("/lesson/ppt", response_model=R)
async def lesson_ppt(
    req: LessonPptRequest,
    _token: None = Depends(require_internal_token),
):
    """基于已生成的教案设计生成分页 PPT 课件提纲（教师确认编辑后发布）。"""
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id)
    try:
        design_text = req.designJson or "{}"
        # 尽力解析教案设计，确保进入 prompt 的是一段可读文本
        try:
            design_obj = json.loads(design_text)
            design_text = json.dumps(design_obj, ensure_ascii=False, indent=2)
        except Exception:  # noqa: BLE001
            pass

        slide_count = max(6, min(30, req.slideCount or 12))
        user_msg = (
            f"课程主题:{req.title or '未指定'}\n"
            f"科室/疾病系统:{req.department or '未指定'}\n"
            f"适用年级:{req.targetGrade or '未指定'}\n"
            f"目标页数:{slide_count} 页（可在此基础上 ±2 页浮动）\n\n"
            f"关联病例上下文:\n{req.caseContext or '无'}\n\n"
            f"已生成教案设计（唯一内容来源，禁止新增教案外知识点）:\n{design_text}\n\n"
            "请严格依据上述教案设计，输出分页 PPT 课件提纲 JSON。"
        )
        messages = [
            {"role": "system", "content": lesson_ppt_prompt()},
            {"role": "user", "content": user_msg},
        ]
        try:
            raw = await llm_client.chat(messages, trace_id=trace_id)
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(trace_id=trace_id) from exc

        result: LessonPptResult = await structured_output.parse_and_validate(
            raw, LessonPptResult, trace_id=trace_id,
        )
        # 规整页序连续递增
        for idx, slide in enumerate(result.slides, 1):
            slide.seq = idx

        safety = safety_policy.check_output(json.dumps(result.model_dump(), ensure_ascii=False))
        if safety.is_blocked:
            raise OutputSchemaInvalidError("课件提纲未通过安全校验，请调整后重试", trace_id)

        log_event(logger, INFO, "lesson_ppt_done", trace_id=trace_id,
                  title=req.title, slides=len(result.slides))
        return R(data=result.model_dump())
    except ApiError as e:
        log_event(logger, WARNING, "lesson_ppt_unavailable", trace_id=trace_id, code=e.code)
        return R(code=e.http_status, message=e.message, data=None)
    except Exception as e:  # noqa: BLE001
        log_event(logger, WARNING, "lesson_ppt_failed", trace_id=trace_id,
                  error=type(e).__name__, msg=str(e))
        return R(code=500, message=f"课件提纲生成失败:{e}", data=None)
    finally:
        reset_context()
