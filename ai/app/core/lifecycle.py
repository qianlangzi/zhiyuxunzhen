"""应用生命周期资源管理

集中管理所有共享异步资源，在应用启动时创建一次，在关闭时优雅释放。
禁止每个请求临时创建 HTTP Client。

当前管理的资源:
- httpx.AsyncClient (共享 HTTP 连接池)
- redis.asyncio.Redis (异步 Redis 客户端)
- ModelGateway、SpringClient、RetrievalService、MilvusRepository
- 可选 LangfuseClient
"""
import logging
from typing import Any

import httpx
import redis.asyncio as aioredis

from app.core.config import settings
from app.adapters.model_gateway import model_gateway
from app.services.backend_client import backend_client
from app.services.milvus_service import milvus_service
from app.services.model_registry import model_registry
from app.services.config_center import config_center
from app.services.rag_service import rag_service

logger = logging.getLogger(__name__)


class ResourceRegistry:
    """共享资源注册表

    在 lifespan 启动时初始化，关闭时释放。
    所有资源通过 app.state 访问，或通过 core/dependencies.py 注入。
    """

    def __init__(self) -> None:
        self.http_client: httpx.AsyncClient | None = None
        self.redis_client: aioredis.Redis | None = None
        # 以下资源在后续 Phase 创建后接入
        self.model_gateway: Any | None = model_gateway
        self.milvus_repository: Any | None = milvus_service
        self.langfuse_client: Any | None = None
        self.spring_client: Any | None = backend_client
        self.retrieval_service: Any | None = rag_service

    async def startup(self) -> None:
        """初始化所有共享资源"""
        logger.info("Starting resource initialization...")

        # 1. HTTP 客户端（共享连接池）
        self.http_client = httpx.AsyncClient(
            limits=httpx.Limits(
                max_connections=settings.httpx_max_connections,
                max_keepalive_connections=settings.httpx_keepalive_connections,
                keepalive_expiry=30,
            ),
            timeout=httpx.Timeout(30.0, connect=5.0),
        )
        logger.info(
            "HTTP client initialized (max_connections=%d)",
            settings.httpx_max_connections,
        )

        # 2. Redis 客户端
        if settings.redis_configured:
            try:
                pool = aioredis.ConnectionPool(
                    host=settings.redis_host,
                    port=settings.redis_port,
                    password=settings.redis_password.get_secret_value() or None,
                    db=settings.redis_db,
                    max_connections=settings.redis_pool_size,
                    decode_responses=True,
                )
                self.redis_client = aioredis.Redis(connection_pool=pool)
                # 测试连接
                await self.redis_client.ping()
                logger.info(
                    "Redis client initialized (host=%s, port=%d)",
                    settings.redis_host,
                    settings.redis_port,
                )
            except Exception as e:
                logger.warning(
                    "Redis connection failed, continuing without Redis: %s", e
                )
                self.redis_client = None
        else:
            logger.info("Redis not configured, skipping initialization")

        # 3. 将共享 HTTP client 注入到 backend_client，避免每次回调临时创建连接池
        backend_client.set_shared_client(self.http_client)

        # 4. 启动模型注册表：从业务中台拉取活跃模型配置并热同步进 settings
        model_registry.start()
        # 5. 启动 AI 配置中心：热同步提示词 / Agent 元参数 / RAG 运行参数
        config_center.start()

        logger.info("Resource initialization complete")

    async def shutdown(self) -> None:
        """优雅关闭所有共享资源"""
        logger.info("Starting resource shutdown...")

        # 按照创建的逆序关闭
        # 先停模型注册表刷新循环，避免关闭期间再拉取
        await model_registry.stop()
        await config_center.stop()

        if self.langfuse_client is not None:
            try:
                flush = getattr(self.langfuse_client, "flush", None)
                if flush is not None:
                    await flush()
            except Exception as e:
                logger.warning("Error closing Langfuse client: %s", e)

        if self.redis_client is not None:
            try:
                await self.redis_client.aclose()
                logger.info("Redis client closed")
            except Exception as e:
                logger.warning("Error closing Redis client: %s", e)

        if self.http_client is not None:
            try:
                await self.http_client.aclose()
                logger.info("HTTP client closed")
            except Exception as e:
                logger.warning("Error closing HTTP client: %s", e)

        logger.info("Resource shutdown complete")


# 全局资源注册表实例
resources = ResourceRegistry()


async def startup() -> None:
    """应用启动时调用"""
    await resources.startup()


async def shutdown() -> None:
    """应用关闭时调用"""
    await resources.shutdown()
