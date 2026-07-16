"""健康检查 + 依赖状态（PRD 4.13.2 运维状态指标来源）"""
from fastapi import APIRouter

from app.core.config import settings
from app.services.llm_client import llm_client
from app.services.rag_service import rag_service
from app.services.milvus_service import milvus_service

router = APIRouter()


@router.get("/health")
async def health():
    """轻量健康检查，不触发外部依赖"""
    return {
        "status": "UP",
        "app": settings.app_name,
        "version": settings.app_version,
        "env": settings.env,
    }


@router.get("/info")
def info():
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "modules": [
            "chat (SSE 多模态问诊 - PRD 4.2)",
            "vision (影像/检验分析 - PRD 4.6)",
            "review/medical_record (智能批阅 - PRD 4.5)",
            "embed/textbook (教材向量化 - PRD 4.4)",
            "learning_path/generate (个性化路径 - PRD 4.12)",
            "daily_case/evaluate (每日一例 - PRD 4.10)",
            "report/generate_review_pdf (复盘报告 - PRD 4.11)",
        ],
    }


@router.get("/status")
async def status():
    """详细依赖状态，供管理驾驶舱展示"""
    milvus_count = await milvus_service.count()
    return {
        "llm_configured": settings.llm_configured,
        "llm_available": llm_client.available,
        "vision_configured": settings.vision_configured,
        "embedding_configured": settings.embedding_configured,
        "rag_available": rag_service.available,
        "milvus_host": f"{settings.milvus_host}:{settings.milvus_port}",
        "milvus_vector_count": milvus_count,
        "fallback_enabled": {
            "llm": settings.enable_llm_fallback,
            "milvus": settings.enable_milvus_fallback,
        },
    }
