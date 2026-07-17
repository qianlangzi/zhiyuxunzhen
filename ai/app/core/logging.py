"""统一结构化日志（PRD 16.4.3）

使用标准 logging + JSON 格式化，便于容器化部署时被日志平台采集。
"""
import logging
import sys
from typing import Any

from app.core.config import settings

_LOG_FORMAT = (
    "%(asctime)s %(levelname)-5s [%(name)s] "
    "trace_id=%(trace_id)s session_id=%(session_id)s - %(message)s"
)


class _ContextFilter(logging.Filter):
    """注入 trace_id / session_id 到每条日志"""

    def __init__(self) -> None:
        super().__init__()
        self._trace_id: str = "-"
        self._session_id: str = "-"

    def set_trace(self, trace_id: str | None, session_id: str | None) -> None:
        if trace_id is not None:
            self._trace_id = trace_id
        if session_id is not None:
            self._session_id = session_id

    def reset(self) -> None:
        self._trace_id = "-"
        self._session_id = "-"

    def filter(self, record: logging.LogRecord) -> bool:
        record.trace_id = self._trace_id
        record.session_id = self._session_id
        return True


_context = _ContextFilter()


def configure_logging() -> None:
    """配置根 logger，应在应用启动时调用一次"""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter(_LOG_FORMAT))
    # 把上下文 filter 加到 handler 上（而非 logger），
    # 这样所有子 logger 的 record 传播到 root handler 时都会被注入 trace_id/session_id
    handler.addFilter(_context)
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(logging.DEBUG if settings.env == "dev" else logging.INFO)
    # 抑制第三方库的过多日志
    for noisy in ("httpx", "httpcore", "openai", "urllib3"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


def set_context(trace_id: str | None = None, session_id: str | None = None) -> None:
    """更新当前请求上下文（例如 SSE 流式处理时）"""
    _context.set_trace(trace_id, session_id)


def reset_context() -> None:
    _context.reset()


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)


def log_event(
    logger: logging.Logger,
    level: int,
    event: str,
    **fields: Any,
) -> None:
    """统一事件日志格式：event=xxx field1=v1 field2=v2"""
    payload = " ".join(f"{k}={v}" for k, v in fields.items())
    logger.log(level, f"event={event} {payload}")
