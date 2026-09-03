"""错题 AI 归因模型（PRD 4.11 错题本 → 学习辅导）"""
from pydantic import BaseModel, Field


class MistakeAnalyzeRequest(BaseModel):
    """单条错题归因请求 —— 对应 Java AiPlatformClient.analyzeMistake"""

    mistakeId: int = Field(description="错题 ID")
    studentId: int = Field(description="学生 ID")
    mistakeType: str = Field(description="diagnosis / history / exam / record / communication")
    knowledgeTag: str | None = Field(default=None, description="关联知识点")
    caseTitle: str | None = Field(default=None, description="病例标题")
    question: str = Field(default="", description="题目/问诊场景描述")
    studentAnswer: str = Field(default="", description="学生作答/脱轨行为")
    standardAnswer: str = Field(default="", description="标准答案/正确路径")
    evidence: str | None = Field(default=None, description="关键证据与脱轨节点")


class MistakeAnalysisResult(BaseModel):
    """错题归因结果（结构化）"""

    mistakeId: int = Field(description="错题 ID")
    rootCause: str = Field(default="", description="为什么错、缺失的知识点")
    explanation: str = Field(default="", description="通俗讲解（概念/正确思路）")
    recommendedTags: list[str] = Field(default_factory=list, description="巩固方向标签")
    practiceHint: str = Field(default="", description="巩固题方向/下一步行动")
    source: str = Field(default="AI", description="AI / RULE")
    status: str = Field(default="SUCCESS", description="SUCCESS / DEGRADED / FAILED")
