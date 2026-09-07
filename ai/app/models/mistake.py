"""错题 AI 归因模型（PRD 4.11 错题本 → 学习辅导）"""
from pydantic import BaseModel, Field


class MistakeAnalyzeRequest(BaseModel):
    """单条错题归因请求 —— 对应 Java AiPlatformClient.analyzeMistake"""

    mistakeId: int = Field(description="错题 ID")
    studentId: int = Field(description="学生 ID")
    mistakeType: str = Field(description="diagnosis / history / exam / record / communication / practice / essay")
    knowledgeTag: str | None = Field(default=None, description="关联知识点")
    caseTitle: str | None = Field(default=None, description="病例标题")
    question: str = Field(default="", description="题目/问诊场景描述")
    studentAnswer: str = Field(default="", description="学生作答/脱轨行为")
    standardAnswer: str = Field(default="", description="标准答案/正确路径")
    evidence: str | None = Field(default=None, description="关键证据与脱轨节点")
    questionType: str = Field(
        default="objective",
        description="objective=客观题/问诊实操（走临床推理五阶段分叉）；subjective=简答论述（走失分维度归因）",
    )
    score: float | None = Field(default=None, description="主观题得分（0-100），仅 subjective 传入")
    essayMistakes: list[dict] = Field(
        default_factory=list,
        description="主观题批阅错误明细（location/type/severity/comment/deduction）",
    )


class MistakeAnalysisResult(BaseModel):
    """错题归因结果（结构化）

    兼容约定：stage / forkPoint / biasType 为新增字段，均有默认值，
    历史已落库的 ai_analysis_json（只有旧四字段）仍可正常解析。
    """

    mistakeId: int = Field(description="错题 ID")
    stage: str = Field(
        default="",
        description="分叉阶段（客观题）information/hypothesis/differential/workup/conclusion；"
                    "失分维度（主观题）completeness/logic/professionalism/expression",
    )
    forkPoint: str = Field(
        default="",
        description="分叉点对照：学生在这一步实际怎么想的 / 正确路径本该怎么走",
    )
    biasType: str = Field(
        default="",
        description="认知偏差：anchoring 锚定 / premature_closure 过早闭合 / availability 可得性 / "
                    "confirmation 确认偏误 / framing 框定效应 / none 无",
    )
    rootCause: str = Field(default="", description="为什么错、缺失的知识点")
    explanation: str = Field(default="", description="通俗讲解（概念/正确思路）")
    recommendedTags: list[str] = Field(default_factory=list, description="巩固方向标签")
    practiceHint: str = Field(default="", description="巩固题方向/下一步行动")
    source: str = Field(default="AI", description="AI / RULE")
    status: str = Field(default="SUCCESS", description="SUCCESS / DEGRADED / FAILED")
