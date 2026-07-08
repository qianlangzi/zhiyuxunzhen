"""
健康检查 + 基础元信息
"""
from fastapi import APIRouter
from app.core.config import settings

router = APIRouter()


@router.get("/health")
def health():
    return {
        "status": "UP",
        "app": settings.app_name,
        "version": settings.app_version,
        "milvus_configured": bool(settings.milvus_host),
        "spark_configured": bool(settings.spark_api_key)
    }


@router.get("/info")
def info():
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "modules": [
            "chat (SSE 多模态问诊 - PRD 4.2)",
            "embed (教材向量化 - PRD 4.4)",
            "review/medical_record (智能批阅 - PRD 4.5)",
            "learning_path/generate (个性化路径 - PRD 4.6)"
        ]
    }
