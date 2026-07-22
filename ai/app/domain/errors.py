"""领域异常类

由 API 层映射为 HTTP 状态码。
这些异常表示业务规则违反，不是系统错误。
"""
from app.core.errors import ApiError, ErrorCode


class EvidenceInsufficientError(ApiError):
    """证据不足错误

    当 RAG 检索结果不足以支持回答时抛出。
    """
    def __init__(self, message: str = "知识库证据不足，无法生成可靠回答。", **kwargs):
        super().__init__(
            code=ErrorCode.KNOWLEDGE_EVIDENCE_INSUFFICIENT,
            message=message,
            http_status=422,
            **kwargs,
        )


class ScoringUnavailableError(ApiError):
    """评分不可用错误

    当模型不可用且无法计算量表分数时抛出。
    禁止返回固定默认分数。
    """
    def __init__(self, message: str = "评分服务暂不可用，请稍后重试或联系教师。", **kwargs):
        super().__init__(
            code=ErrorCode.AI_UNAVAILABLE,
            message=message,
            http_status=503,
            **kwargs,
        )


class StateConflictError(ApiError):
    """状态冲突错误

    当操作违反业务状态规则时抛出（如对已完成的任务再次操作）。
    """
    def __init__(self, message: str = "操作与当前状态冲突。", **kwargs):
        super().__init__(
            code=ErrorCode.TASK_ALREADY_COMPLETED,
            message=message,
            http_status=409,
            **kwargs,
        )


class OutputRejectedError(ApiError):
    """输出被拒绝错误

    当 SP Agent 的回复未通过输出校验时抛出。
    """
    def __init__(self, message: str = "AI 输出未通过校验，已拦截。", **kwargs):
        super().__init__(
            code=ErrorCode.OUTPUT_REJECTED,
            message=message,
            http_status=422,
            **kwargs,
        )


class RetrievalUnavailableError(ApiError):
    """检索不可用错误

    当 Embedding 或 Milvus 不可用时抛出。
    禁止返回零向量并继续当作正常检索。
    """
    def __init__(self, message: str = "知识检索服务暂不可用。", **kwargs):
        super().__init__(
            code=ErrorCode.RETRIEVAL_UNAVAILABLE,
            message=message,
            http_status=503,
            **kwargs,
        )
