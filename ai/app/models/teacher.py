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

类型宽容层（LooseStr / LooseStrList / LooseInt / LooseBool）
----------------------------------------------------------
这些模型校验的是**大模型生成的输出**，而 LLM 对 JSON Schema 的类型理解天然不稳定：
同一份提示词下 `"age"` 可能输出 `58`（数字）也可能输出 `"58"`（字符串），
数组字段可能被压成一个顿号分隔的字符串。Pydantic v2 默认**不允许 int → str 的强转**
（int 会直接报 `string_type`），于是模型一次性的类型漂移就会让整条 AI 链路 422 失败：
教师端表现为"输出校验失败: Input should be a valid string"（2026-09-12 线上复现，
本地 10 次调用 5 次命中，`loc=('age',)`，input=58）。

因此所有 **模型产出字段** 一律用宽容类型：数字/布尔折叠为字符串、字符串拆为列表，
只在确实无法归一（对象、深层结构）时才交给 Pydantic 报错。
注意：请求模型（*Request）由 Spring Boot 构造，入参不需要宽容。
"""
import re
from typing import Annotated, Any

from pydantic import BaseModel, BeforeValidator, Field


# ---------- 类型宽容层 ----------

def _coerce_str(value: Any) -> Any:
    """数字/布尔 → 字符串；None 与容器类型原样返回给 Pydantic 报错"""
    if isinstance(value, bool):
        return "是" if value else "否"
    if isinstance(value, (int, float)):
        # 58.0 → "58"，58 → "58"，避免"58.0 岁"这类脏值
        return str(int(value)) if float(value).is_integer() else str(value)
    return value


_SPLIT_RE = re.compile(r"[、,，;；/|\n]+")


def _coerce_str_list(value: Any) -> Any:
    """字符串 → 列表（按顿号/逗号/分号/斜杠/换行拆分）；列表内元素逐个折叠为字符串"""
    if isinstance(value, str):
        parts = [p.strip() for p in _SPLIT_RE.split(value)]
        return [p for p in parts if p]
    if isinstance(value, list):
        return [_coerce_str(v) for v in value]
    return value


def _coerce_int(value: Any) -> Any:
    """'10分' / 'P12' / 10.0 → 10；无法提取数字时原样返回给 Pydantic 报错"""
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        matched = re.search(r"-?\d+", value)
        return int(matched.group()) if matched else value
    return value


_TRUE_WORDS = {"true", "yes", "y", "1", "是", "通过", "pass", "对"}
_FALSE_WORDS = {"false", "no", "n", "0", "否", "不通过", "fail", "错"}


def _coerce_bool(value: Any) -> Any:
    """'是' / '通过' → True；'否' → False；其它原样返回给 Pydantic 报错"""
    if isinstance(value, str):
        word = value.strip().lower()
        if word in _TRUE_WORDS:
            return True
        if word in _FALSE_WORDS:
            return False
    return value


LooseStr = Annotated[str, BeforeValidator(_coerce_str)]
LooseStrOpt = Annotated[str | None, BeforeValidator(_coerce_str)]
LooseStrList = Annotated[list[str], BeforeValidator(_coerce_str_list)]
LooseInt = Annotated[int, BeforeValidator(_coerce_int)]
LooseIntOpt = Annotated[int | None, BeforeValidator(_coerce_int)]
LooseBool = Annotated[bool, BeforeValidator(_coerce_bool)]


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

    book_name: LooseStr
    chapter: LooseStrOpt = None
    page_number: LooseIntOpt = None
    chunk_text: LooseStrOpt = None


class ScoringPoint(BaseModel):
    """评分要点（供 AI 评判），对应移动端 sp_config_screen 的评分要点列表"""

    label: LooseStr = Field(default="", description="要点名，如：心电图判读")
    fullMark: LooseInt = Field(default=0, description="满分")
    criteria: LooseStr = Field(default="", description="给分标准")
    deduct: LooseStrOpt = Field(default=None, description="扣分说明（可选）")


class CaseDraftResult(BaseModel):
    """AI 生成的病例草稿（教师审核后入库，不进 SP 运行）

    除展示用 patientProfile 文本外，还输出结构化的患者画像字段，便于移动端在
    教师确认后直接自动填充 SP 配置台表单（整表填充），而非仅填充展示子集。
    结构化字段均为可选，模型遗漏时移动端保留原值，不影响 schema 校验。
    """

    patientProfile: LooseStr = Field(description="患者画像文本")
    hiddenDisease: LooseStr = Field(description="隐藏疾病/真实诊断")
    standardPath: LooseStrList = Field(default_factory=list, description="标准问诊检查诊断路径")
    presetExams: list[dict] = Field(
        default_factory=list,
        description="[{\"name\":\"\",\"cost\":0,\"isKey\":true,\"result\":\"\"}]",
    )
    knowledgeTags: LooseStrList = Field(default_factory=list, description="知识点标签")
    citations: list[CaseDraftCitation] = Field(default_factory=list, description="教材溯源")

    # ---- 供表单整表填充的结构化患者画像（均可选）----
    age: LooseStrOpt = Field(default=None, description="年龄，如：58")
    gender: LooseStrOpt = Field(default=None, description="性别：男/女")
    occupation: LooseStrOpt = Field(default=None, description="职业")
    chiefComplaint: LooseStrOpt = Field(default=None, description="主诉")
    presentIllness: LooseStrOpt = Field(default=None, description="现病史摘要")
    pastHistory: LooseStrOpt = Field(default=None, description="既往史")
    allergy: LooseStrOpt = Field(default=None, description="过敏史，无则'否认'")
    personality: LooseStrList = Field(default_factory=list, description="性格/沟通风格标签")

    # ---- 评分依据（可选）----
    referenceAnswer: LooseStrOpt = Field(default=None, description="标准答案/诊断要点")
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

    topic: LooseStr = Field(description="建议主题")
    suggestion: LooseStr = Field(description="具体建议")
    evidence: LooseStr = Field(description="依据的统计数据/事实")


class ClassInsightResult(BaseModel):
    """AI 归纳的班级学情洞察（基于真实统计，不新增数据）"""

    weaknessAnalysis: LooseStr = Field(description="班级薄弱点分析")
    teachingSuggestions: list[TeachingSuggestion] = Field(default_factory=list)
    recommendedFocus: LooseStr = Field(description="优先整改方向")


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

    scoreItem: LooseStr = Field(description="针对的 AI 批阅项/扣分点")
    verdict: LooseStr = Field(description="agree|disagree|uncertain")
    reason: LooseStr = Field(description="复核理由")
    textbookRef: LooseStrOpt = Field(default=None, description="教材出处")


class ReviewAssistResult(BaseModel):
    """AI 复核建议（仅供教师参考，不产生新分数）"""

    suggestions: list[ReviewSuggestion] = Field(default_factory=list)
    commentDraft: LooseStr = Field(description="评语草稿，供教师修改")

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

    caseId: LooseInt
    reason: LooseStr = Field(description="推荐理由")
    matchedWeakness: LooseStr = Field(description="针对的班级薄弱点")


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

    item: LooseStr = Field(description="检查项名称")
    passed: LooseBool = Field(description="是否通过")
    reason: LooseStr = Field(description="结论/建议")
    textbookRef: LooseStrOpt = Field(default=None, description="教材出处")


class QualityResult(BaseModel):
    """AI 病例质检结果"""

    overallPass: LooseBool = Field(description="是否整体通过")
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

    type: LooseStr = Field(description="single|multi|short")
    stem: LooseStr = Field(description="题干")
    options: LooseStrList = Field(default_factory=list, description="选项，简答题为空")
    answer: LooseStr = Field(description="正确答案：单选为选项序号，多选为序号列表，简答为标准答案")
    explanation: LooseStr = Field(description="解析")
    knowledgeTag: LooseStr = Field(description="关联知识点")
    textbookRef: LooseStrOpt = Field(default=None, description="教材出处")


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

    item: LooseStr = Field(description="材料名称，如 胸部X光片")
    kind: LooseStr = Field(default="image", description="建议形式：image|pdf|audio|video|text")
    reason: LooseStr = Field(default="", description="为什么要这份材料（结合病例一句话）")
    priority: LooseInt = Field(default=2, description="1必备 2建议 3可选")


class MaterialAdviceResult(BaseModel):
    """病例素材建议清单"""

    suggestions: list[MaterialAdviceItem] = Field(default_factory=list)
    summary: LooseStr = Field(default="", description="一句话总体建议")
