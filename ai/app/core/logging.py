"""统一结构化日志

使用标准 logging + JSON 格式化，便于容器化部署时被日志平台采集。
请求上下文使用 contextvars 实现，确保 50 并发 SSE 下 trace_id 不串扰。
"""
import logging
import sys
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
