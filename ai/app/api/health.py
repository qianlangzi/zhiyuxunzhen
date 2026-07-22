"""健康检查 + 依赖状态（PRD 4.13.2 运维状态指标来源）"""
from fastapi import APIRouter, Depends, Response, status as http_status

from app.core.config import settings
from app.services.llm_client import llm_client
from app.services.rag_service import rag_service
from app.services.milvus_service import milvus_service
from app.core.security import require_operator

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


@router.get("/health/live")
async def live():
    return await health()


@router.get("/ready")
async def ready(response: Response):
    """Dependency-aware readiness; an unconfigured LLM is reported but optional."""
    checks = {
        "llm": {"configured": settings.llm_configured, "available": llm_client.available},
        "embedding": {"configured": settings.embedding_configured, "available": rag_service.available},
        "milvus": {"configured": True, "available": None},
        "backend": {"configured": bool(settings.backend_callback_url), "available": None},
    }
    try:
        await milvus_service.count()
        checks["milvus"]["available"] = True
    except Exception:  # noqa: BLE001
        checks["milvus"]["available"] = False
    required_ok = checks["backend"]["configured"] and checks["milvus"]["available"] is not False
    response.status_code = http_status.HTTP_200_OK if required_ok else http_status.HTTP_503_SERVICE_UNAVAILABLE
    return {"status": "READY" if required_ok else "NOT_READY", "checks": checks}


@router.get("/health/ready")
async def health_ready(response: Response):
    return await ready(response)


@router.get("/status")
async def status(_operator: bool = Depends(require_operator)):
    """详细依赖状态，供管理驾驶舱展示"""
    try:
        milvus_count = await milvus_service.count()
        milvus_error = None
    except Exception as exc:  # noqa: BLE001
        milvus_count = None
        milvus_error = type(exc).__name__
    return {
        "llm_configured": settings.llm_configured,
        "llm_available": llm_client.available,
        "vision_configured": settings.vision_configured,
        "embedding_configured": settings.embedding_configured,
        "rag_available": rag_service.available,
        "milvus_host": f"{settings.milvus_host}:{settings.milvus_port}",
        "milvus_vector_count": milvus_count,
        "milvus_error": milvus_error,
        "fallback_enabled": {
            "llm": settings.enable_llm_fallback,
            "milvus": settings.enable_milvus_fallback,
        },
    }
