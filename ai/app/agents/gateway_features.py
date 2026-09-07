"""Agent 网关的功能注册表（阶段3）：把散点 endpoint 按 6 个 Agent 分组收拢。

只做「分组 + 复用」：每个 action 指向现有 endpoint 的请求模型与处理函数，
网关直接调用 handler，保留其全部副作用（回调、SSE 契约、降级语义），零业务重写。

分组 code（与业务中台 agent_config.code / 管理端 Agent 定义对应）：
- consultation 问诊咨询   / mentor 导师 / evaluator 评测批阅
- coach 学习教练 / teacher 教师助手 / lesson 备课教案 / companion 陪伴
"""
from typing import Any

from pydantic import BaseModel

from app.api import (
    alert,
    chat,
    companion,
    daily_case,
    diagnosis,
    essay_review,
    learning_path,
    lesson,
    mistake,
    mr,
    paper,
    recommendation,
    review,
    session,
    teacher,
)
from app.services.config_center import STRATEGY_CODE, AgentSpec


class Feature:
    """一个可经网关调用的能力：请求模型 + 复用后的处理函数 + 是否流式。"""

    __slots__ = ("group", "model", "handler", "is_stream")

    def __init__(
        self,
        group: str,
        model: type[BaseModel],
        handler: Any,
        is_stream: bool = False,
    ) -> None:
        self.group = group
        self.model = model
        self.handler = handler
        self.is_stream = is_stream


def _f(group: str, model: type[BaseModel], handler: Any, is_stream: bool = False) -> Feature:
    return Feature(group=group, model=model, handler=handler, is_stream=is_stream)


# group code -> {action -> Feature}
FEATURES: dict[str, dict[str, Feature]] = {
    "consultation": {
        "stream": _f("consultation", chat.ChatRequest, chat.chat_stream_internal, is_stream=True),
        "opening": _f("consultation", chat.ChatRequest, chat.chat_opening),
        "sync": _f("consultation", chat.ChatRequest, chat.chat_sync),
    },
    "mentor": {
        "update_tree": _f("mentor", chat.ChatRequest, chat.chat_mentor),
    },
    "evaluator": {
        "medical_record": _f("evaluator", review.ReviewRequest, review.review_medical_record),
        "essay": _f("evaluator", essay_review.EssayReviewRequest, essay_review.review_essay),
        "session": _f("evaluator", session.EvaluateArchiveRequest, session.evaluate_and_archive),
        "daily_case": _f("evaluator", daily_case.DailyCaseFullRequest, daily_case.evaluate_daily_case),
        "mr_hint": _f("evaluator", mr.MrSegmentHintRequest, mr.segment_hint),
        "mr_review": _f("evaluator", mr.MrReviewRequest, mr.review_record),
    },
    "coach": {
        "learning_path": _f("coach", learning_path.LearningPathRequest, learning_path.generate_learning_path),
        "recommend_weakness": _f("coach", recommendation.RecommendRequest, recommendation.recommend_weakness),
        "mistake_analyze": _f("coach", mistake.MistakeAnalyzeRequest, mistake.analyze_mistake),
        "weakness_diagnosis": _f("coach", diagnosis.WeaknessDiagnosisRequest, diagnosis.diagnose_weakness),
        "paper_generate": _f("coach", paper.PaperGenerateRequest, paper.generate_paper),
        "alert": _f("coach", alert.AlertInterventionRequest, alert.alert_intervention),
    },
    "teacher": {
        "case_draft": _f("teacher", teacher.CaseDraftRequest, teacher.generate_case_draft),
        "class_insight": _f("teacher", teacher.ClassInsightRequest, teacher.class_insight),
        "review_assist": _f("teacher", teacher.ReviewAssistRequest, teacher.review_assist),
        "recommend_cases": _f("teacher", teacher.RecommendCasesRequest, teacher.recommend_cases),
        "quality_check": _f("teacher", teacher.QualityRequest, teacher.quality_check),
        "practice_questions": _f("teacher", teacher.PracticeQuestionsRequest, teacher.practice_questions),
        "material_advice": _f("teacher", teacher.MaterialAdviceRequest, teacher.material_advice),
    },
    "lesson": {
        "lesson_design": _f("lesson", lesson.LessonDesignRequest, lesson.lesson_design),
        "lesson_guide": _f("lesson", lesson.LessonGuideRequest, lesson.lesson_guide),
        "lesson_merge": _f("lesson", lesson.LessonMergeRequest, lesson.lesson_merge),
        "lesson_ppt": _f("lesson", lesson.LessonPptRequest, lesson.lesson_ppt),
    },
    "companion": {
        "sync": _f("companion", companion.CompanionChatRequest, companion.companion_sync),
        "stream": _f("companion", companion.CompanionChatRequest, companion.companion_stream_internal, is_stream=True),
    },
}

# group code -> 内置默认 Agent 定义（业务中台热覆盖合并到 config_center.resolve_agent_spec）
GROUPS: dict[str, AgentSpec] = {
    "consultation": AgentSpec(code="consultation", name="问诊咨询", strategy=STRATEGY_CODE,
                              temperature=0.7, max_tokens=1024),
    "mentor": AgentSpec(code="mentor", name="导师", strategy=STRATEGY_CODE,
                        temperature=0.6, max_tokens=1024),
    "evaluator": AgentSpec(code="evaluator", name="评测批阅", strategy=STRATEGY_CODE,
                           temperature=0.2, max_tokens=2048),
    "coach": AgentSpec(code="coach", name="学习教练", strategy=STRATEGY_CODE,
                       temperature=0.4, max_tokens=2048),
    "teacher": AgentSpec(code="teacher", name="教师助手", strategy=STRATEGY_CODE,
                         temperature=0.3, max_tokens=2048),
    "lesson": AgentSpec(code="lesson", name="备课教案", strategy=STRATEGY_CODE,
                        temperature=0.5, max_tokens=3072),
    "companion": AgentSpec(code="companion", name="陪伴", strategy=STRATEGY_CODE,
                           temperature=0.8, max_tokens=1024),
}


def default_action_for(group: str) -> str | None:
    """单 action 分组返回其唯一 action；多 action 分组返回 None（需显式指定）。"""
    actions = FEATURES.get(group) or {}
    if len(actions) == 1:
        return next(iter(actions))
    return None