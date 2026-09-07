"""教师端 AI 辅助功能模型（PRD 9.3 扩展）

对应 Spring Boot 教师端 6 个 AI 辅助能力的请求/响应结构：
1. AI 生成 SP 病例草稿
2. AI 班级学情洞察
3. AI 复核辅助
4. AI 推荐作业病例
5. AI 病例质检
6. AI 自动生成练习题

所有模型强调"可溯源"：涉及医学事实的字段必须携带 textbookRef（教材名/章节/页码），
LLM 只做归纳与生成草稿，最终由教师审核入库，避免低质幻觉。
"""
from pydantic import BaseModel, Field


# ---------- 1. AI 生成 SP 病例草稿 ----------

class CaseDraftRequest(BaseModel):
    """对应 Java TeacherAiService.generateCaseDraft"""

    chiefComplaint: str = Field(description="主诉，如：胸痛 2 小时伴大汗")
    department: str = Field(description="科室，如：心血管内科")
    difficulty: int = Field(default=2, description="1简单 2标准 3困难")
    teachingGoals: list[str] = Field(default_factory=list, description="教学目标/知识点")
    remark: str | None = Field(default=None, description="教师补充说明/备注（可选）")


class CaseDraftCitation(BaseModel):
    """病例草稿中的教材溯源"""

    book_name: str
    chapter: str | None = None
    page_number: int | None = None
    chunk_text: str | None = None


class ScoringPoint(BaseModel):
    """评分要点（供 AI 评判），对应移动端 sp_config_screen 的评分要点列表"""

    label: str = Field(default="", description="要点名，如：心电图判读")
    fullMark: int = Field(default=0, description="满分")
    criteria: str = Field(default="", description="给分标准")
    deduct: str | None = Field(default=None, description="扣分说明（可选）")


class CaseDraftResult(BaseModel):
    """AI 生成的病例草稿（教师审核后入库，不进 SP 运行）

    除展示用 patientProfile 文本外，还输出结构化的患者画像字段，便于移动端在
    教师确认后直接自动填充 SP 配置台表单（整表填充），而非仅填充展示子集。
    结构化字段均为可选，模型遗漏时移动端保留原值，不影响 schema 校验。
    """

    patientProfile: str = Field(description="患者画像文本")
    hiddenDisease: str = Field(description="隐藏疾病/真实诊断")
    standardPath: list[str] = Field(default_factory=list, description="标准问诊检查诊断路径")
    presetExams: list[dict] = Field(
        default_factory=list,
        description="[{\"name\":\"\",\"cost\":0,\"isKey\":true,\"result\":\"\"}]",
    )
    knowledgeTags: list[str] = Field(default_factory=list, description="知识点标签")
    citations: list[CaseDraftCitation] = Field(default_factory=list, description="教材溯源")

    # ---- 供表单整表填充的结构化患者画像（均可选）----
    age: str | None = Field(default=None, description="年龄，如：58")
    gender: str | None = Field(default=None, description="性别：男/女")
    occupation: str | None = Field(default=None, description="职业")
    chiefComplaint: str | None = Field(default=None, description="主诉")
    presentIllness: str | None = Field(default=None, description="现病史摘要")
    pastHistory: str | None = Field(default=None, description="既往史")
    allergy: str | None = Field(default=None, description="过敏史，无则'否认'")
    personality: list[str] = Field(default_factory=list, description="性格/沟通风格标签")

    # ---- 评分依据（可选）----
    referenceAnswer: str | None = Field(default=None, description="标准答案/诊断要点")
    scoringPoints: list[ScoringPoint] = Field(
        default_factory=list,
        description="可评判的评分要点：复杂病例可拆分为多个要点",
    )


# ---------- 2. AI 班级学情洞察 ----------

class StatItem(BaseModel):
    """班级统计项（由 Spring Boot 聚合真实数据，LLM 只做归纳）"""

    label: str
    value: str


class CommonMistakeItem(BaseModel):
    """共性错题/漏问项"""

    type: str
    description: str
    count: int


class ClassInsightRequest(BaseModel):
    """对应 Java TeacherAiService.classInsight"""

    className: str = Field(default="", description="班级名")
    stats: list[StatItem] = Field(default_factory=list, description="真实统计")
    osceDimensionScores: dict = Field(default_factory=dict, description="OSCE 维度均分")
    commonMistakes: list[CommonMistakeItem] = Field(default_factory=list, description="共性错题")


class TeachingSuggestion(BaseModel):
    """单条教学建议，必须关联具体统计证据"""

    topic: str = Field(description="建议主题")
    suggestion: str = Field(description="具体建议")
    evidence: str = Field(description="依据的统计数据/事实")


class ClassInsightResult(BaseModel):
    """AI 归纳的班级学情洞察（基于真实统计，不新增数据）"""

    weaknessAnalysis: str = Field(description="班级薄弱点分析")
    teachingSuggestions: list[TeachingSuggestion] = Field(default_factory=list)
    recommendedFocus: str = Field(description="优先整改方向")


# ---------- 3. AI 复核辅助 ----------

class ReviewAssistRequest(BaseModel):
    """对应 Java TeacherAiService.reviewAssist"""

    instanceId: int
    medicalRecordText: str = Field(description="学生大病历原文")
    aiScore: float = Field(description="AI 批阅总分")
    aiMistakes: list[dict] = Field(
        default_factory=list,
        description="AI 批阅错误项：[{\"location\":\"\",\"type\":\"\",\"severity\":\"\",\"comment\":\"\",\"deduction\":0}]",
    )
    caseContext: str = Field(default="", description="病例标准路径上下文")


class ReviewSuggestion(BaseModel):
    """单条复核建议，必须带教材溯源"""

    scoreItem: str = Field(description="针对的 AI 批阅项/扣分点")
    verdict: str = Field(description="agree|disagree|uncertain")
    reason: str = Field(description="复核理由")
    textbookRef: str | None = Field(default=None, description="教材出处")


class ReviewAssistResult(BaseModel):
    """AI 复核建议（仅供教师参考，不产生新分数）"""

    suggestions: list[ReviewSuggestion] = Field(default_factory=list)
    commentDraft: str = Field(description="评语草稿，供教师修改")

    model_config = {"extra": "forbid"}


# ---------- 4. AI 推荐作业病例 ----------

class WeaknessTag(BaseModel):
    """班级薄弱知识点"""

    tag: str
    score: float = Field(description="薄弱度 0-1，越大越弱")


class CandidateCase(BaseModel):
    """候选病例（来自病例库）"""

    caseId: int
    title: str
    knowledgeTags: list[str] = Field(default_factory=list)
    difficulty: int = Field(default=2)


class RecommendCasesRequest(BaseModel):
    """对应 Java TeacherAiService.recommendCases"""

    classId: int
    weaknesses: list[WeaknessTag] = Field(default_factory=list, description="班级薄弱点")
    candidateCases: list[CandidateCase] = Field(default_factory=list, description="候选病例库")


class CaseRecommendation(BaseModel):
    """单条病例推荐"""

    caseId: int
    reason: str = Field(description="推荐理由")
    matchedWeakness: str = Field(description="针对的班级薄弱点")


class RecommendCasesResult(BaseModel):
    """AI 推荐的作业病例"""

    recommendations: list[CaseRecommendation] = Field(default_factory=list)


# ---------- 5. AI 病例质检 ----------

class QualityRequest(BaseModel):
    """对应 Java TeacherAiService.qualityCheck"""

    caseId: int
    title: str = Field(default="")
    hiddenDisease: str = Field(description="隐藏疾病")
    standardPath: list[str] = Field(default_factory=list)
    presetExams: list[dict] = Field(default_factory=list)
    knowledgeTags: list[str] = Field(default_factory=list)


class QualityCheckItem(BaseModel):
    """单条质检项"""

    item: str = Field(description="检查项名称")
    passed: bool = Field(description="是否通过")
    reason: str = Field(description="结论/建议")
    textbookRef: str | None = Field(default=None, description="教材出处")


class QualityResult(BaseModel):
    """AI 病例质检结果"""

    overallPass: bool = Field(description="是否整体通过")
    checklist: list[QualityCheckItem] = Field(default_factory=list)


# ---------- 6. AI 自动生成练习题 ----------

class PracticeQuestionsRequest(BaseModel):
    """对应 Java TeacherAiService.practiceQuestions"""

    caseId: int
    hiddenDisease: str = Field(description="隐藏疾病")
    standardPath: list[str] = Field(default_factory=list)
    knowledgeTags: list[str] = Field(default_factory=list)


class PracticeQuestion(BaseModel):
    """单道练习题"""

    type: str = Field(description="single|multi|short")
    stem: str = Field(description="题干")
    options: list[str] = Field(default_factory=list, description="选项，简答题为空")
    answer: str = Field(description="正确答案：单选为选项序号，多选为序号列表，简答为标准答案")
    explanation: str = Field(description="解析")
    knowledgeTag: str = Field(description="关联知识点")
    textbookRef: str | None = Field(default=None, description="教材出处")


class PracticeQuestionsResult(BaseModel):
    """AI 生成的练习题"""

    questions: list[PracticeQuestion] = Field(default_factory=list)

# ---------- 7. 病例素材智能推荐（多模态问诊配套） ----------

class MaterialAdviceRequest(BaseModel):
    """对应 Java TeacherAiService.materialAdvice"""

    caseId: int = Field(default=0)
    title: str = Field(default="", description="病例标题")
    department: str = Field(default="", description="科室")
    complaint: str = Field(default="", description="主诉")
    hiddenDisease: str = Field(default="", description="隐藏疾病/真实诊断")
    presentIllness: str = Field(default="", description="现病史摘要")
    existingExams: list[str] = Field(default_factory=list, description="已配置的检查项名称")


class MaterialAdviceItem(BaseModel):
    """单条素材建议"""

    item: str = Field(description="材料名称，如 胸部X光片")
    kind: str = Field(default="image", description="建议形式：image|pdf|audio|video|text")
    reason: str = Field(default="", description="为什么要这份材料（结合病例一句话）")
    priority: int = Field(default=2, description="1必备 2建议 3可选")


class MaterialAdviceResult(BaseModel):
    """病例素材建议清单"""

    suggestions: list[MaterialAdviceItem] = Field(default_factory=list)
    summary: str = Field(default="", description="一句话总体建议")
