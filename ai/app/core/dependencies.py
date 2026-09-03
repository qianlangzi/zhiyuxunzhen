"""FastAPI 依赖注入函数

从 app.state 获取共享资源，避免模块级单例导入。
每个请求通过 Depends() 获取所需资源。
"""
from fastapi import Request
from typing import Any

from app.core.config import Settings, get_settings


def get_settings_dep() -> Settings:
    """获取应用配置"""
    return get_settings()


def get_http_client(request: Request) -> Any:
    """获取共享 httpx.AsyncClient"""
    client = getattr(request.app.state, "http_client", None)
    if client is None:
        raise RuntimeError("HTTP client not initialized. Check lifecycle startup.")
    return client


def get_redis_client(request: Request) -> Any:
    """获取共享 Redis 客户端
    
    Returns None if Redis is not configured.
    """
    return getattr(request.app.state, "redis_client", None)


def get_spring_client(request: Request) -> Any:
    """获取 Spring Boot 内部客户端。"""
    return getattr(request.app.state, "spring_client", None)


def get_model_gateway(request: Request) -> Any:
    """获取模型网关。"""
    return getattr(request.app.state, "model_gateway", None)


def get_retrieval_service(request: Request) -> Any:
    """获取知识检索服务。"""
    return getattr(request.app.state, "retrieval_service", None)


def get_milvus_repository(request: Request) -> Any:
    """获取 Milvus repository。"""
    return getattr(request.app.state, "milvus_repository", None)
