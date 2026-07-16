"""
智愈寻真 - AI 中台 (FastAPI)

对应 PRD 3.3 / 9.2 / 9.3：负责大模型调度、多模态处理、向量检索、智能体编排。

启动：
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from app.api import chat, daily_case, embed, health, learning_path, report, review, vision
from app.core.config import settings
from app.core.logging import configure_logging, get_logger, log_event
from logging import INFO, WARNING


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
    yield
    log_event(logger, INFO, "ai_stopped", app=settings.app_name)


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="智愈寻真 - AI 中台，负责大模型调度、RAG、智能体编排与 SSE 流式输出",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- 路由注册 ----------
app.include_router(health.router, tags=["meta"])
app.include_router(chat.router, tags=["chat"])
app.include_router(vision.router, tags=["vision"])
app.include_router(review.router, tags=["review"])
app.include_router(embed.router, tags=["embed"])
app.include_router(learning_path.router, tags=["learning_path"])
app.include_router(daily_case.router, tags=["daily_case"])
app.include_router(report.router, tags=["report"])


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
