"""统一错误码和异常体系

所有 API 错误都使用 ApiError 异常，由 main.py 中的异常处理器
统一转换为 HTTP 响应。客户端永远收到稳定的 code 和 message，
不收到供应商异常、URL、堆栈或内部配置。

错误响应格式:
{
    "error": {
        "code": "AI_UNAVAILABLE",
        "message": "当前 AI 服务暂不可用，请稍后重试。",
        "traceId": "uuid"
    }
}
"""
import uuid
from typing import Any


class ErrorCode:
    """机器可读错误码常量"""

    AUTH_REQUIRED = "AUTH_REQUIRED"
    FORBIDDEN = "FORBIDDEN"
    SESSION_NOT_FOUND = "SESSION_NOT_FOUND"
    SESSION_NOT_OWNED = "SESSION_NOT_OWNED"
    AI_UNAVAILABLE = "AI_UNAVAILABLE"
    AI_DEGRADED = "AI_DEGRADED"
    AI_BUDGET_EXCEEDED = "AI_BUDGET_EXCEEDED"
    KNOWLEDGE_EVIDENCE_INSUFFICIENT = "KNOWLEDGE_EVIDENCE_INSUFFICIENT"
    OUTPUT_SCHEMA_INVALID = "OUTPUT_SCHEMA_INVALID"
    SAFETY_BLOCKED = "SAFETY_BLOCKED"
    TASK_NOT_FOUND = "TASK_NOT_FOUND"
    TASK_ALREADY_COMPLETED = "TASK_ALREADY_COMPLETED"
    DEPENDENCY_UNAVAILABLE = "DEPENDENCY_UNAVAILABLE"
    OUTPUT_REJECTED = "OUTPUT_REJECTED"
    RETRIEVAL_UNAVAILABLE = "RETRIEVAL_UNAVAILABLE"
    RATE_LIMITED = "RATE_LIMITED"


class ApiError(Exception):
    """API 统一异常基类

    所有业务异常都应继承此类或直接抛出。
    main.py 中的异常处理器会将其转换为标准错误响应。

    Attributes:
        code: 机器可读错误码（如 AUTH_REQUIRED）
        message: 用户可读的错误消息
        http_status: HTTP 状态码
        trace_id: 请求追踪 ID
        details: 可选的额外详情（不会暴露给客户端）
    """

    def __init__(
        self,
        code: str,
        message: str,
        http_status: int = 400,
        trace_id: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        self.code = code
        self.message = message
        self.http_status = http_status
        self.trace_id = trace_id or str(uuid.uuid4())
        self.details = details
        super().__init__(message)

    def to_response(self) -> dict[str, Any]:
        """转换为客户端响应格式"""
        return {
            "error": {
                "code": self.code,
                "message": self.message,
                "traceId": self.trace_id,
            }
        }


class BackendDependencyError(ApiError):
    """Spring Boot 中台依赖错误

    当 SpringClient 调用失败时抛出。
    不吞掉异常并假装成功。
    """

    def __init__(
        self,
        message: str = "业务中台暂不可用",
        trace_id: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(
            code=ErrorCode.DEPENDENCY_UNAVAILABLE,
            message=message,
            http_status=502,
            trace_id=trace_id,
            details=details,
        )


class ModelUnavailableError(ApiError):
    """模型不可用错误

    当 LLM 供应商不可用时抛出。
    评分和批阅必须返回此错误，不能返回伪造分数。
    """

    def __init__(
        self,
        message: str = "当前 AI 服务暂不可用，请稍后重试。",
        trace_id: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(
            code=ErrorCode.AI_UNAVAILABLE,
            message=message,
            http_status=503,
            trace_id=trace_id,
            details=details,
        )


class RetrievalUnavailableError(ApiError):
    """Embedding 或向量检索依赖不可用。"""

    def __init__(self, message: str = "知识检索服务暂不可用", trace_id: str | None = None) -> None:
        super().__init__(
            code=ErrorCode.RETRIEVAL_UNAVAILABLE,
            message=message,
            http_status=503,
            trace_id=trace_id,
        )


class SafetyBlockedError(ApiError):
    """安全策略拦截"""

    def __init__(
        self,
        message: str = "检测到敏感内容，已按安全策略拦截。",
        trace_id: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(
            code=ErrorCode.SAFETY_BLOCKED,
            message=message,
            http_status=400,
            trace_id=trace_id,
            details=details,
        )


class OutputSchemaInvalidError(ApiError):
    """模型输出 Schema 校验失败"""

    def __init__(
        self,
        message: str = "AI 输出格式不符合预期，请重试。",
        trace_id: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(
            code=ErrorCode.OUTPUT_SCHEMA_INVALID,
            message=message,
            http_status=422,
            trace_id=trace_id,
            details=details,
        )


class BudgetExceededError(ApiError):
    """Token 预算超限"""

    def __init__(
        self,
        message: str = "今日 AI 使用额度已用完，请明天再试。",
        trace_id: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(
            code=ErrorCode.AI_BUDGET_EXCEEDED,
            message=message,
            http_status=429,
            trace_id=trace_id,
            details=details,
        )


class TaskNotFoundError(ApiError):
    """任务不存在"""

    def __init__(
        self,
        task_id: str,
        trace_id: str | None = None,
    ) -> None:
        super().__init__(
            code=ErrorCode.TASK_NOT_FOUND,
            message=f"任务 {task_id} 不存在",
            http_status=404,
            trace_id=trace_id,
        )
