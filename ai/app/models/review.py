"""大病历批阅相关模型（PRD 4.4）"""
from pydantic import BaseModel, Field


class ReviewRequest(BaseModel):
    """对应 Java AiPlatformClient.reviewMedicalRecord"""

    instanceId: int
    medicalRecordText: str = Field(min_length=1)


class MistakeItem(BaseModel):
    """单条错误项"""

    location: str = Field(description="错误位置，如段落名+句号区间")
    type: str = Field(
        description="format / medical_fact / logic / ddx / humanity / other"
    )
    severity: str = Field(description="low / medium / high")
    comment: str = Field(description="扣分依据与修改建议")
    deduction: float = Field(default=0.0, description="建议扣分")


class ReviewResult(BaseModel):
    """批阅结果（同步返回 + 回调 Spring Boot）"""

    instanceId: int
    totalScore: float = Field(description="0-100")
    mistakes: list[MistakeItem] = []
    reviewComment: str = Field(description="综合评语")


class LearningFact(BaseModel):
    """学生薄弱知识点事实（来自业务中台 student_weakness）"""

    knowledgeTag: str = Field(description="薄弱知识点")
    weaknessScore: float | None = Field(default=None, description="掌握度 0~1，越低越薄弱")
    evidenceCount: int | None = Field(default=None, description="证据数")


class MistakeFact(BaseModel):
    """近期错题要点事实（来自业务中台 student_mistakes）"""

    knowledgeTag: str = Field(description="错题关联知识点")
    note: str = Field(description="错题要点/学生作答摘录")


class CandidateTextbook(BaseModel):
    """候选教材（防幻觉，仅允许从中推荐）"""

    id: int
    title: str


class CandidateQuestion(BaseModel):
    """候选基础题（防幻觉，仅允许从中推荐）"""

    id: int
    title: str
    difficulty: int | None = None


class CandidateCase(BaseModel):
    """候选病例（防幻觉，仅允许从中推荐）"""

    id: int
    title: str
    difficulty: str | None = None


class LearningFacts(BaseModel):
    """学生事实快照：由业务中台组装，作为学习路径 Agent 的真实输入"""

    weaknesses: list[LearningFact] = Field(default_factory=list, description="薄弱知识点（升序，最薄弱在前）")
    mistakes: list[MistakeFact] = Field(default_factory=list, description="近期错题要点")
    learnedChapters: list[str] = Field(default_factory=list, description="已学教材章节/已完成内容")
    candidateTextbooks: list[CandidateTextbook] = Field(default_factory=list)
    candidateQuestions: list[CandidateQuestion] = Field(default_factory=list)
    candidateCases: list[CandidateCase] = Field(default_factory=list)


class LearningPathRequest(BaseModel):
    """对应 Java AiPlatformClient.generateLearningPath —— 携带学生事实快照"""

    studentId: int
    facts: LearningFacts | None = None


class PathStep(BaseModel):
    """递进学习路径中的一步"""

    order: int = Field(description="步骤序号，从 1 开始")
    stage: str = Field(
        description="knowledge_diagnosis / textbook / simple_case / standard_case / comprehensive_case"
    )
    title: str = Field(description="步骤标题")
    goal: str = Field(description="本步目标")
    detail: str = Field(description="本步内容/行动指引")
    evidence: str = Field(description="依据：关联的薄弱点/错题/教材")
    targetMetric: str = Field(description="完成判定指标")
    resources: list[dict] = Field(default_factory=list, description="关联资源：{type: textbook|question|case, id, title}")


class LearningPathResult(BaseModel):
    """个性化补救路径（结构化）"""

    studentId: int
    diagnosis: str = Field(default="", description="知识水平诊断（总述）")
    weakKnowledgeTags: list[str] = []
    pathSteps: list[PathStep] = Field(default_factory=list, description="递进路径步骤")
    recommendedSteps: list[str] = Field(
        default_factory=list,
        description="兼容旧版：文本化递进步骤（教材复习→简单病例→标准病例→综合病例）",
    )
    recommendedCases: list[int] = Field(default_factory=list, description="病例 ID")
    citations: list = []


class WeaknessDiagnosisRequest(BaseModel):
    """学情诊断请求（P0-3）—— 对应 Java AiPlatformClient.weaknessDiagnosis
    输入统计薄弱点（STAT）+ 近期错题，LLM 输出整体诊断与逐点 AI 归因。"""

    studentId: int = Field(description="学生 ID")
    weaknesses: list[LearningFact] = Field(default_factory=list, description="统计薄弱点（掌握度越低越薄弱）")
    mistakes: list[MistakeFact] = Field(default_factory=list, description="近期错题要点")


class WeaknessDiagnosisItem(BaseModel):
    """单个薄弱点的 AI 归因"""

    knowledgeTag: str = Field(description="薄弱知识点")
    rootCause: str = Field(default="", description="为什么薄弱（缺哪个知识点/环节）")
    suggestion: str = Field(default="", description="怎么补（行动建议）")


class WeaknessDiagnosisResult(BaseModel):
    """学情诊断结果（统计兜底 + AI 归因合并）"""

    overall: str = Field(default="", description="整体学情诊断（2-3 句）")
    items: list[WeaknessDiagnosisItem] = Field(default_factory=list, description="逐薄弱点 AI 归因")
    source: str = Field(default="AI", description="AI / RULE")
    status: str = Field(default="SUCCESS", description="SUCCESS / DEGRADED / FAILED")
