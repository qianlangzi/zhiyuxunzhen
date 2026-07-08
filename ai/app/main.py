"""
智愈寻真 - AI 中台 (FastAPI)

对应 PRD 3.3: 只负责大模型调度、多模态处理、向量检索。
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import chat, health
from app.core.config import settings

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="智愈寻真 - AI 中台,负责星火大模型调度与 Milvus 检索"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

app.include_router(health.router, tags=["meta"])
app.include_router(chat.router, tags=["chat"])


@app.get("/")
def root():
    return {"app": settings.app_name, "version": settings.app_version}
