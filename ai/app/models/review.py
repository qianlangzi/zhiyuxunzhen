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


class LearningPathRequest(BaseModel):
    """对应 Java AiPlatformClient.generateLearningPath"""

    studentId: int


class LearningPathResult(BaseModel):
    """个性化补救路径"""

    studentId: int
    weakKnowledgeTags: list[str] = []
    recommendedSteps: list[str] = Field(
        default_factory=list,
        description="按教材复习→简单病例→标准病例→综合病例递进",
    )
    recommendedCases: list[int] = Field(default_factory=list, description="病例 ID")
    citations: list = []
