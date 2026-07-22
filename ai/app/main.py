"""
智愈寻真 - AI 中台 (FastAPI)

对应 PRD 3.3 / 9.2 / 9.3：负责大模型调度、多模态处理、向量检索、智能体编排。

启动：
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from starlette.middleware.base import BaseHTTPMiddleware

from app.api import chat, daily_case, embed, health, knowledge, learning_path, report, review, tasks, vision
from app.core import lifecycle
from app.core.config import settings
from app.core.errors import ApiError
from app.core.logging import configure_logging, get_logger, log_event, reset_context, set_context
from logging import INFO, WARNING


class RequestContextMiddleware(BaseHTTPMiddleware):
    """为每个请求生成/透传 trace_id，写入 contextvars"""

    async def dispatch(self, request: Request, call_next):
        # 从请求头获取或生成 trace_id
        trace_id = request.headers.get("X-Trace-Id", str(uuid.uuid4()))

        # 设置 contextvars 上下文
        set_context(trace_id=trace_id)

        try:
            response = await call_next(request)
        finally:
            reset_context()

        # 将 trace_id 写入响应头
        response.headers["X-Trace-Id"] = trace_id
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期钩子"""
    configure_logging()
    logger = get_logger(__name__)
    log_event(logger, INFO, "ai_started",
              app=settings.app_name, version=settings.app_version,
              env=settings.env,
              llm_configured=settings.llm_configured,
              milvus_host=settings.milvus_host)
    await lifecycle.startup()
    # 将资源注册到 app.state 供依赖注入使用
    app.state.http_client = lifecycle.resources.http_client
    app.state.redis_client = lifecycle.resources.redis_client
    app.state.model_gateway = lifecycle.resources.model_gateway
    app.state.spring_client = lifecycle.resources.spring_client
    app.state.retrieval_service = lifecycle.resources.retrieval_service
    app.state.milvus_repository = lifecycle.resources.milvus_repository
    try:
        yield
    finally:
        await lifecycle.shutdown()
        log_event(logger, INFO, "ai_stopped", app=settings.app_name)


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="智愈寻真 - AI 中台，负责大模型调度、RAG、智能体编排与 SSE 流式输出",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allowed_origins if settings.cors_allowed_origins else ["*"],
    allow_credentials=bool(settings.cors_allowed_origins),  # Only with explicit origins
    allow_methods=["*"],
    allow_headers=["*"],
)
# RequestContextMiddleware 最后添加 → 最外层执行，确保 trace_id 在 CORS 预检前就绑定
app.add_middleware(RequestContextMiddleware)

# ---------- 路由注册 ----------
app.include_router(health.router, tags=["meta"])
app.include_router(chat.router, tags=["chat"])
app.include_router(vision.router, tags=["vision"])
app.include_router(review.router, tags=["review"])
app.include_router(embed.router, tags=["embed"])
app.include_router(learning_path.router, tags=["learning_path"])
app.include_router(daily_case.router, tags=["daily_case"])
app.include_router(report.router, tags=["report"])
app.include_router(tasks.router, tags=["tasks"])
app.include_router(knowledge.router, tags=["knowledge"])


@app.get("/")
def root():
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs",
        "health": "/health",
        "status": "/status",
    }


# ---------- 全局异常处理 ----------
@app.exception_handler(ApiError)
async def api_error_handler(request: Request, exc: ApiError):
    logger = get_logger(__name__)
    log_event(logger, WARNING, "api_error", path=request.url.path,
              code=exc.code, trace_id=exc.trace_id)
    return JSONResponse(status_code=exc.http_status, content=exc.to_response())


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(request: Request, exc: RequestValidationError):
    trace_id = request.headers.get("X-Trace-Id", str(uuid.uuid4()))
    logger = get_logger(__name__)
    log_event(logger, WARNING, "request_validation_error",
              path=request.url.path, trace_id=trace_id, error=str(exc)[:500])
    return JSONResponse(
        status_code=422,
        content={"error": {
            "code": "VALIDATION_ERROR",
            "message": "请求参数校验失败",
            "traceId": trace_id,
        }},
    )


@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    logger = get_logger(__name__)
    log_event(logger, WARNING, "validation_error",
              path=request.url.path, error=str(exc)[:500])
    return JSONResponse(
        status_code=422,
        content={"code": 422, "message": "请求参数校验失败", "data": exc.errors()},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger = get_logger(__name__)
    log_event(logger, WARNING, "unhandled_error",
              path=request.url.path, error=type(exc).__name__, msg=str(exc)[:500])
    return JSONResponse(
        status_code=500,
        content={"code": 500, "message": f"服务内部错误：{type(exc).__name__}", "data": None},
    )
