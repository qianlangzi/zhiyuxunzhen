"""统一结构化日志

使用标准 logging + JSON 格式化，便于容器化部署时被日志平台采集。
请求上下文使用 contextvars 实现，确保 50 并发 SSE 下 trace_id 不串扰。
"""
import logging
import sys
import uuid
from contextvars import ContextVar
from typing import Any

from app.core.config import settings

_LOG_FORMAT = (
    "%(asctime)s %(levelname)-5s [%(name)s] "
    "trace_id=%(trace_id)s session_id=%(session_id)s - %(message)s"
)

# 使用 contextvars 替代进程级共享实例变量
# 每个 asyncio Task 有独立的 contextvars 上下文，不会串扰
_trace_id_var: ContextVar[str] = ContextVar("trace_id", default="-")
_session_id_var: ContextVar[str] = ContextVar("session_id", default="-")
# Agent 采样参数（由 agent_gateway 写入，llm_client 读取为默认值）
# 用途：让「AI 配置中心」热改的 temperature/max_tokens/model 真正作用到
# 经网关下发的所有 LLM 调用，而无需逐个修改 handler 内部采样参数。
_agent_temperature_var: ContextVar[float | None] = ContextVar("agent_temperature", default=None)
_agent_max_tokens_var: ContextVar[int | None] = ContextVar("agent_max_tokens", default=None)
_agent_model_var: ContextVar[str | None] = ContextVar("agent_model", default=None)


class _ContextVarFilter(logging.Filter):
    """从 contextvars 注入 trace_id / session_id 到每条日志

    与旧的 _ContextFilter 不同，这个 Filter 不存储任何状态，
    而是从 contextvars 读取当前协程的上下文。
    这确保了 50 并发 SSE 连接下每个请求的 trace 独立。
    """

    def filter(self, record: logging.LogRecord) -> bool:
        record.trace_id = _trace_id_var.get()
        record.session_id = _session_id_var.get()
        return True


_context = _ContextVarFilter()

# 需要过滤的敏感字段模式
_SENSITIVE_PATTERNS = (
    "password",
    "passwd",
    "secret",
    "token",
    "jwt",
    "api_key",
    "apikey",
    "authorization",
    "bearer",
)


def _is_sensitive_key(key: str) -> bool:
    """检查字段名是否敏感"""
    key_lower = key.lower()
    return any(p in key_lower for p in _SENSITIVE_PATTERNS)


def _mask_value(value: Any) -> str:
    """脱敏处理敏感值"""
    s = str(value)
    if len(s) <= 4:
        return "***"
    return s[:2] + "***" + s[-2:]


def configure_logging() -> None:
    """配置根 logger，应在应用启动时调用一次"""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter(_LOG_FORMAT))
    handler.addFilter(_context)
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(logging.DEBUG if settings.env == "dev" else logging.INFO)
    # 抑制第三方库的过多日志
    for noisy in ("httpx", "httpcore", "openai", "urllib3"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


def set_context(trace_id: str | None = None, session_id: str | None = None) -> None:
    """更新当前请求上下文（基于 contextvars，协程安全）

    在 asyncio 环境中，每个 Task 有独立的 contextvars 上下文，
    因此并发请求之间不会互相覆盖。
    """
    if trace_id is not None:
        _trace_id_var.set(trace_id)
    if session_id is not None:
        _session_id_var.set(session_id)


def reset_context() -> None:
    """重置当前请求上下文"""
    _trace_id_var.set("-")
    _session_id_var.set("-")


def ensure_trace_id() -> str:
    """返回当前请求的 trace_id；缺失时生成并写入上下文。

    用途：``app.main:RequestContextMiddleware`` 已优先从入站 ``X-Trace-Id`` 头注入
    trace（无头则生成一条全程统一的 uuid）。handler 若在此处重新 ``str(uuid.uuid4())``
    会丢弃入站透传值，跨系统日志无法按同一 trace 关联。改用它即可在保留链路透传的
    同时，对不走 HTTP（如后台 worker）的场景优雅 fallback 到本地新生成的 id。
    """
    current = _trace_id_var.get()
    if current and current != "-":
        return current
    trace_id = str(uuid.uuid4())
    _trace_id_var.set(trace_id)
    return trace_id


def set_agent_sampling(
    temperature: float | None = None,
    max_tokens: int | None = None,
    model: str | None = None,
) -> None:
    """写入当前 Agent 的采样参数到请求上下文（供 llm_client 作为默认值回退）。

    入参全为 None 时视为清除；由 agent_gateway 在调用 handler 前写入、
    handler 返回后清除，经网关下发的 LLM 调用即会以此为默认采样。
    """
    _agent_temperature_var.set(temperature)
    _agent_max_tokens_var.set(max_tokens)
    _agent_model_var.set(model)


def get_agent_sampling() -> tuple[float | None, int | None, str | None]:
    """读取当前请求上下文的 Agent 采样参数（无则返回三个 None）。"""
    return (
        _agent_temperature_var.get(),
        _agent_max_tokens_var.get(),
        _agent_model_var.get(),
    )


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)


def log_event(
    logger: logging.Logger,
    level: int,
    event: str,
    **fields: Any,
) -> None:
    """统一事件日志格式：event=xxx field1=v1 field2=v2

    敏感字段（password/token/secret 等）自动脱敏。
    """
    safe_fields = {}
    for k, v in fields.items():
        if _is_sensitive_key(k):
            safe_fields[k] = _mask_value(v)
        else:
            safe_fields[k] = v
    payload = " ".join(f"{k}={v}" for k, v in safe_fields.items())
    logger.log(level, f"event={event} {payload}")
