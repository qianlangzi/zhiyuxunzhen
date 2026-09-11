"""问诊 SSE 相关模型"""
from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    """单条对话消息"""

    role: str = Field(description="student / sp / mentor / system")
    content: str


class ChatRequest(BaseModel):
    """问诊 SSE 请求体（PRD 9.2）

    2026-09-03：case_id / messages 放宽为可选——mentor 按需小结接口只依赖
    session_id 回查会话上下文，不带病例与消息也能通过入参校验；正常对话链路
    仍由调用方传全字段，行为不变。
    """

    case_id: int | None = None
    session_id: int
    student_id: int | None = None
    messages: list[ChatMessage] = Field(default_factory=list)
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
    # 仅 /internal/vision/analyze 使用：由业务中台在完成移动端鉴权后填入；
    # 公网 /v1/ai/vision/analyze 一律忽略该字段，学生身份只取自 JWT。
    student_id: int | None = Field(default=None, description="学生 userId（内部调用专用）")


class VisionAnalysisResult(BaseModel):
    """多模态分析结果"""

    finding: str = Field(description="读图结论（教学用语，附带免责声明）")
    citations: list = Field(default_factory=list, description="RAG 溯源，可选")
    safety_blocked: bool = False
    status: str = Field(default="OK", description="OK/DEGRADED/FAILED")
    source: str = Field(default="VISION_LLM", description="结果来源")
    degraded: bool = False
