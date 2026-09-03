"""可替换的 trace/span 接口；Langfuse 接入前保持 no-op。"""
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator


@asynccontextmanager
async def span(name: str, *, trace_id: str = "-", **attributes: object) -> AsyncIterator[dict[str, object]]:
    context = {"name": name, "trace_id": trace_id, **attributes}
    try:
        yield context
    finally:
        context["finished"] = True
