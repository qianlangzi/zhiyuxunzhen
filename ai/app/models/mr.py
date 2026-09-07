"""每日病历（大病历训练闭环）模型：段落教练 + 结构化批阅"""
from pydantic import BaseModel, Field


class MrSegmentHintRequest(BaseModel):
    """段落教练请求：对应 Java AiPlatformClient.mrSegmentHint"""

    scheduleId: int = Field(description="每日一例排期ID")
    studentId: int = Field(description="学生ID")
    segmentKey: str = Field(description="段落key，如 history_present")
    segmentName: str = Field(default="", description="段落中文名，如 现病史")
    segmentSpec: str = Field(default="", description="该段书写规范说明")
    hintLevel: int = Field(default=1, description="提示等级1追问/2定向提示/3示范片段")
    draft: str = Field(default="", description="学生该段已写内容")
    caseSummary: str = Field(default="", description="病例摘要（患者画像）")
    keyFindings: str = Field(default="", description="关键检查结果")
    materials: list[str] = Field(default_factory=list, description="问诊对话素材（供素材回捞）")


class MrSegmentHintResult(BaseModel):
    """段落教练结果"""

    type: str = Field(description="question|hint|example|praise")
    text: str = Field(default="", description="面向学生的引导文本")
    quoteMaterials: list[str] = Field(default_factory=list, description="可回捞的问诊原话")


class MrSegmentDefect(BaseModel):
    """单条缺陷"""

    tag: str = Field(description="缺陷代码，如 CC_TOO_LONG")
    level: int = Field(default=1, description="1轻微 2一般 3严重")
    msg: str = Field(default="", description="缺陷说明")
    suggest: str = Field(default="", description="改进建议")


class MrSegmentReview(BaseModel):
    """单段评审"""

    key: str = Field(description="段落key")
    score: float = Field(description="该段得分")
    full: float = Field(default=0, description="该段满分")
    comment: str = Field(default="", description="段内点评")
    defects: list[MrSegmentDefect] = Field(default_factory=list)


class MrReviewRequest(BaseModel):
    """结构化批阅请求：对应 Java AiPlatformClient.mrReview"""

    recordId: int = Field(default=0, description="病历记录ID（用于回调定位，可0）")
    scheduleId: int = Field(description="每日一例排期ID")
    studentId: int = Field(description="学生ID")
    record: dict[str, str] = Field(description="九段内容 {segmentKey: content}")
    caseContext: str = Field(default="", description="病例摘要+关键检查（批阅依据）")
    standardAnswer: str = Field(default="", description="标准诊断要点（金标准）")
    defectTags: str = Field(default="", description="可用缺陷字典描述（空则用内置）")


class MrReviewResult(BaseModel):
    """结构化批阅结果"""

    totalScore: float = Field(description="总分（0-100）")
    confidence: float = Field(default=0.0, description="批阅置信度0-1，>=0.85教师端可免复核")
    segments: list[MrSegmentReview] = Field(default_factory=list)
    defectTags: list[str] = Field(default_factory=list, description="命中的缺陷代码汇总")
    reviewComment: str = Field(default="", description="总评")
