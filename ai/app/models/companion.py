"""AI 学伴（学习陪伴）请求/响应模型（P1-2）。

角色区别于 SP（标准病人）：SP 扮演"病人"配合问诊；学伴是"平辈学习伙伴"，
闲聊式陪伴 + 基于学生错题/进度/薄弱点给策略建议。
"""
from pydantic import BaseModel, Field


class CompanionMessage(BaseModel):
    """单条对话消息"""

    role: str = Field(description="user / assistant")
    content: str


class CompanionChatRequest(BaseModel):
    """AI 学伴对话请求。

    message: 学生当前输入（闲聊/困惑/请求建议）
    session_id: 可选，后端学伴会话 ID（companion_conversation.id，由 Spring Boot 透传）；
              供对话后记忆抽取回填 source_session_id（来源溯源），缺失时该字段为空
    history: 可选，多轮对话历史 [{role, content}]，支持追问与指代消解
    context: 可选，学生学情上下文（薄弱点/近期错题/进度），由业务中台组装后注入，
             学伴据此给个性化建议。为空时学伴仅作通用陪伴。
    """

    student_id: int | None = Field(default=None, description="学生 ID")
    message: str = Field(min_length=1, max_length=2000)
    image_url: str | None = Field(
        default=None, description="可选图片地址（多模态），与 message 一起作为用户消息"
    )
    session_id: int | None = Field(default=None)
    history: list[dict[str, str]] = Field(
        default_factory=list, description="历史对话，role ∈ {user, assistant}"
    )
    context: dict[str, object] = Field(
        default_factory=dict, description="学生学情上下文（weaknesses/mistakes/progress 等）"
    )


class CompanionChatResult(BaseModel):
    """AI 学伴对话结果（同步接口聚合返回）"""

    reply: str = Field(default="", description="学伴回复全文")
    session_id: int | None = Field(default=None)
    degraded: bool = Field(default=False, description="是否走规则降级")
    source: str = Field(default="AI", description="AI / RULE")
    status: str = Field(default="SUCCESS", description="SUCCESS / DEGRADED / FAILED")
