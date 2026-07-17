"""教材向量化与每日一例、报告相关模型"""
from pydantic import BaseModel, Field


class EmbedTextbookRequest(BaseModel):
    """对应 Java AiPlatformClient.embedTextbook"""

    textbookId: int
    fileUrl: str = Field(description="教材 PDF 可访问 URL")


class EmbedTextbookResult(BaseModel):
    textbookId: int
    chunkCount: int = Field(description="切块数量")
    vectorCount: int = Field(description="实际入库向量数")
    status: str = Field(description="success / partial / failed")
    message: str | None = None


class DailyCaseEvaluateRequest(BaseModel):
    """对应 Java AiPlatformClient.evaluateDailyCase"""

    studentId: int
    caseId: int
    answer: str = Field(description="学生选择的诊断/检查")


class DailyCaseEvaluation(BaseModel):
    """每日一例判题结果"""

    studentId: int
    caseId: int
    correct: bool
    correctAnswer: str
    explanation: str = Field(description="避坑点与解析")
    textbookRef: str | None = Field(default=None, description="教材出处")


class ReportRequest(BaseModel):
    """对应 Java AiPlatformClient.generateReviewPdf"""

    sessionId: int


class ReportResult(BaseModel):
    """AI 复盘报告内容（PDF 由 Java 端渲染）"""

    sessionId: int
    title: str
    overview: str = Field(description="训练概览")
    typicalMistakes: list[str] = []
    standardPath: list[str] = []
    textbookRefs: list[str] = Field(default_factory=list, description="教材页码溯源")
    nextSteps: list[str] = []
    disclaimer: str = "本报告仅供医学思维训练使用，不具备临床诊疗效力。"
