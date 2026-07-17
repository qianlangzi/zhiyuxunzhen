"""问诊 SSE 相关模型"""
from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    """单条对话消息"""

    role: str = Field(description="student / sp / mentor / system")
    content: str


class ChatRequest(BaseModel):
    """问诊 SSE 请求体（PRD 9.2）"""

    case_id: int
    session_id: int
    student_id: int | None = None
    messages: list[ChatMessage]
    image_url: str | None = None
    image_bbox: list[float] | None = Field(
        default=None, description="[x, y, w, h] 相对坐标，PRD 5.2"
    )


class VisionAnalyzeRequest(BaseModel):
    """多模态分析请求（PRD 9.2）"""

    session_id: int
    image_url: str = Field(description="图片可访问 URL")
    image_bbox: list[float] | None = None
    student_note: str | None = Field(default=None, description="学生圈画时的备注")


class VisionAnalysisResult(BaseModel):
    """多模态分析结果"""

    finding: str = Field(description="读图结论（教学用语，附带免责声明）")
    citations: list = Field(default_factory=list, description="RAG 溯源，可选")
    safety_blocked: bool = False
