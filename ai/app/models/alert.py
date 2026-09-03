"""学情预警：AI 干预建议生成模型（助教：学情精准诊断）"""
from pydantic import BaseModel, Field


class AlertInterventionRequest(BaseModel):
    """对应 Java AiPlatformClient.alertIntervention"""

    studentName: str = Field(default="", description="学生姓名")
    riskRules: list[dict] = Field(
        default_factory=list,
        description="触发预警的规则明细 [{\"type\":\"osce_low\",\"level\":3,\"detail\":\"连续3次OSCE总分<60\"}]",
    )
    weaknesses: list[dict] = Field(
        default_factory=list,
        description="薄弱知识点 [{\"knowledgeTag\":\"\",\"proficiency\":0.45}]",
    )
    recentMistakes: list[dict] = Field(
        default_factory=list,
        description="近期错题 [{\"type\":\"\",\"knowledgeTag\":\"\",\"studentAnswer\":\"\"}]",
    )
    recommendedCases: list[dict] = Field(
        default_factory=list, description="候选病例 [{\"id\":1,\"title\":\"\",\"knowledgeTags\":[]}]"
    )
    textbookRefs: list[dict] = Field(
        default_factory=list, description="候选教材引用 [{\"book_name\":\"\",\"chapter\":\"\",\"page_number\":0}]"
    )


class AlertInterventionResult(BaseModel):
    """AI 生成的个性化干预建议（教师参考，可缓存）"""

    riskSummary: str = Field(default="", description="学生风险概况（1-2 句）")
    interventions: list[dict] = Field(
        default_factory=list, description="[{\"action\":\"\",\"reason\":\"\",\"target\":\"\"}]"
    )
    recommendedCases: list[int] = Field(default_factory=list, description="推荐病例 ID 列表（仅从候选选择）")
    textbookRefs: list[dict] = Field(
        default_factory=list, description="推荐教材章节 [{\"book_name\":\"\",\"chapter\":\"\",\"page_number\":0}]"
    )
