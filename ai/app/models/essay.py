"""主观题（简答/论述）批阅模型（助教：作业与试题批改）"""
from pydantic import BaseModel, Field


class EssayReviewRequest(BaseModel):
    """对应 Java AiPlatformClient.reviewEssay"""

    question: str = Field(default="", description="题目内容")
    scoringPoints: str = Field(default="", description="教师自定义评分要点（JSON 字符串）")
    studentAnswer: str = Field(default="", description="学生答案")
    caseContext: str = Field(default="", description="病例/题干上下文（可选）")
    textbookRefs: list[dict] = Field(default_factory=list, description="RAG 教材引用锚点")


class EssayDimension(BaseModel):
    """单维度评分"""

    name: str = Field(description="维度名：要点完整性/逻辑性/专业性/表达")
    score: float = Field(description="得分")
    maxScore: float = Field(description="满分")
    basis: str = Field(default="", description="得分依据（引用学生答案原文或评分要点）")
    suggestion: str = Field(default="", description="改进建议")


class EssayMistake(BaseModel):
    """具体错误"""

    location: str = Field(default="", description="错误位置/涉及要点")
    type: str = Field(default="other", description="factual/logic/incomplete/expression/other")
    severity: str = Field(default="medium", description="low/medium/high")
    comment: str = Field(default="", description="错误说明与正确表述")
    deduction: float = Field(default=0, description="扣分")


class EssayReviewResult(BaseModel):
    """AI 主观题批阅结果（教师复核后入库）"""

    totalScore: float = Field(description="总分（0-100）")
    dimensions: list[EssayDimension] = Field(default_factory=list, description="维度评分")
    mistakes: list[EssayMistake] = Field(default_factory=list, description="错误列表")
    reviewComment: str = Field(default="", description="综合评语")
