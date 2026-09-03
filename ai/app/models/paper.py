"""AI 组卷模型（P2-4 学生自测卷 · AI 选题组卷）"""
from pydantic import BaseModel, Field


class PaperCandidate(BaseModel):
    """候选题目（业务中台从审核通过的题库抽取，AI 只做选择防幻觉）"""

    id: int = Field(description="题目 ID")
    knowledgeTag: str = Field(default="", description="知识点")
    difficulty: int | None = Field(default=None, description="1简单 2标准 3困难")
    questionType: str = Field(default="", description="single_choice / judgment")
    title: str = Field(default="", description="题干（截断用于组卷判断）")


class PaperGenerateRequest(BaseModel):
    """AI 组卷请求 —— 对应 Java AiPlatformClient.generatePaper"""

    studentId: int = Field(description="学生 ID")
    count: int = Field(default=10, ge=1, le=20, description="目标题量")
    difficulty: int | None = Field(default=None, description="难度偏好 1/2/3")
    focusTags: list[str] = Field(default_factory=list, description="薄弱知识点")
    candidates: list[PaperCandidate] = Field(default_factory=list, description="题库候选")


class PaperGenerateResult(BaseModel):
    """AI 组卷结果（只返回选题，题目内容由业务中台按 ID 解析）"""

    paperTitle: str = Field(default="", description="自测卷标题")
    selectedIds: list[int] = Field(default_factory=list, description="选中的题目 ID 列表")
    rationale: str = Field(default="", description="组卷思路说明")
    source: str = Field(default="AI", description="AI / RULE")
    status: str = Field(default="SUCCESS", description="SUCCESS / DEGRADED / FAILED")
