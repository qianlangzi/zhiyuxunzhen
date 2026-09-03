"""智能备课：AI 教学设计生成与对话式引导模型（助教核心）"""
from pydantic import BaseModel, Field


class LessonDesignRequest(BaseModel):
    """对应 Java AiPlatformClient.lessonDesign"""

    title: str = Field(default="", description="备课标题/课程主题")
    department: str = Field(default="", description="科室/疾病系统")
    targetGrade: str = Field(default="", description="适用年级")
    teachingGoals: list[str] = Field(default_factory=list, description="教学目标")
    caseContext: str = Field(default="", description="关联病例上下文（JSON 字符串）")
    textbookRefs: list[dict] = Field(default_factory=list, description="RAG 教材引用锚点")
    studentProfile: str = Field(default="", description="学情数据（JSON 字符串，来自系统真实数据，未指定为空）")
    lessonDuration: int = Field(default=45, description="课时时长（分钟）")
    materialRefs: list[dict] = Field(
        default_factory=list,
        description="备课包已上传的多模态素材 [{title,materialType,fileUrl}]（pdf/ppt 作教材锚点，image 走 VLM 识别后并入上下文）",
    )


class LessonDesignRef(BaseModel):
    book_name: str
    chapter: str | None = None
    page_number: int | None = None


class LessonDesignResult(BaseModel):
    """AI 生成的医学教案（教师审核编辑后存入 lesson_plan.ai_design_json）"""

    teachingObjectives: list[str] = Field(default_factory=list, description="教学目标")
    keyPoints: list[str] = Field(default_factory=list, description="教学重点")
    keyDifficultPoints: list[str] = Field(default_factory=list, description="教学难点")
    lessonOutline: list[dict] = Field(
        default_factory=list,
        description="教学过程[{\"phase\":\"导入|讲授|病例讨论|技能训练|小结\",\"duration\":0,\"content\":\"\"}]",
    )
    caseDiscussion: list[str] = Field(default_factory=list, description="病例讨论题")
    skillTraining: list[dict] = Field(
        default_factory=list, description="技能训练环节[{\"name\":\"\",\"description\":\"\",\"duration\":0}]"
    )
    spInterviewDesign: list[str] = Field(default_factory=list, description="SP 问诊设计要点")
    boardDesign: str = Field(default="", description="板书设计")
    homeworkSuggestions: list[str] = Field(default_factory=list, description="课后作业布置")
    teachingReflection: str = Field(default="", description="教学反思建议")
    textbookRefs: list[LessonDesignRef] = Field(default_factory=list, description="教材出处")
    studentProfileNote: str = Field(default="", description="学情数据使用说明（哪些来自系统学情，哪些待补充）")


class LessonGuideRequest(BaseModel):
    """向导式备课对话（无状态：每次请求携带已确认要素 + 用户最新回答）"""

    title: str = Field(default="", description="备课标题/课程主题（已确认值）")
    confirmed: dict = Field(default_factory=dict, description="已确认要素 {\"key\":\"value\"}")
    userReply: str = Field(default="", description="用户对本轮问题的回答/补充")
    step: int = Field(default=0, description="当前引导步骤（0 开始）")


class LessonGuideResult(BaseModel):
    """对话式引导结果"""

    question: str = Field(default="", description="AI 提出的下一个问题（complete=true 时为空）")
    field: str = Field(default="", description="本轮确认的要素键（topic/textbook/classInfo/duration/emphasis/extra）")
    options: list[str] = Field(default_factory=list, description="快捷选项（可为空）")
    optionsHint: str = Field(default="", description="快捷选项说明（如：从我的教材中选择）")
    multiSelect: bool = Field(
        default=False, description="当前问题是否可多选（重难点偏好/其他要求等允许多选的情境为 true）"
    )
    confirmed: dict = Field(default_factory=dict, description="更新后的全部已确认要素（每轮回传，后端持久化）")
    complete: bool = Field(default=False, description="要素是否已齐全，可以生成教案")
    summary: dict = Field(default_factory=dict, description="需求确认单（complete=true 时返回全部要素）")
    missing: list[str] = Field(default_factory=list, description="仍未确认的要素（complete=false 时提示）")


class LessonMergeRequest(BaseModel):
    """AI 合并多份教案（按优先级从高到低传入待合并的设计结果）"""

    title: str = Field(default="", description="合并后教案标题（空则沿用优先级最高教案标题）")
    department: str = Field(default="", description="科室/疾病系统")
    targetGrade: str = Field(default="", description="适用年级")
    lessonDuration: int = Field(default=45, description="课时时长（分钟）")
    designs: list[dict] = Field(
        default_factory=list,
        description="待合并教案的 ai_design_json 列表（按优先级从高到低排列）",
    )


class LessonPptRequest(BaseModel):
    """AI 生成课件素材/PPT 提纲（基于已生成教案设计，教师确认编辑后使用）"""

    title: str = Field(default="", description="备课标题/课程主题")
    department: str = Field(default="", description="科室/疾病系统")
    targetGrade: str = Field(default="", description="适用年级")
    designJson: str = Field(default="", description="已生成的教案设计 ai_design_json（JSON 字符串）")
    caseContext: str = Field(default="", description="关联病例上下文（JSON 字符串，可为空）")
    slideCount: int = Field(default=12, description="PPT 建议页数（默认 12 页，范围 6~30）")


class LessonSlide(BaseModel):
    """单页课件：标题 + 要点 + 讲稿备注 + 建议配套素材"""

    seq: int = Field(default=0, description="页序（从 1 开始）")
    phase: str = Field(default="", description="所属环节（导入/讲授/病例讨论/技能训练/小结）")
    title: str = Field(default="", description="本页标题（须与教案环节一致）")
    bullets: list[str] = Field(default_factory=list, description="本页展示要点（每题一句话）")
    speakerNotes: str = Field(default="", description="讲稿备注/讲解提示")
    materialNote: str = Field(default="", description="建议配套课件素材/图示（可空）")


class LessonPptResult(BaseModel):
    """AI 生成的 PPT 课件提纲（教师确认编辑后存入 lesson_plan.ppt_outline_json）"""

    title: str = Field(default="", description="课件标题")
    overview: str = Field(default="", description="课件整体说明（涵盖范围/适用场景/课时）")
    slides: list[LessonSlide] = Field(default_factory=list, description="分页课件提纲")
    notes: str = Field(default="", description="课件使用建议（发布/课堂使用注意事项）")
