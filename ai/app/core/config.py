"""AI 中台全局配置

所有敏感凭证通过环境变量注入；为方便本地与容器内运行，未配置 LLM 凭证时
系统进入"降级模式"，使用规则 mock 兜底，保证链路可联调。
"""
from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # ---------- 服务 ----------
    app_name: str = "zhiyu-ai"
    app_version: str = "1.0.0"
    env: Literal["dev", "prod"] = "dev"

    # ---------- 大模型（OpenAI 兼容协议，支持星火/通义/DeepSeek/本地 vLLM）----------
    # 星火 OpenAI 兼容端点：https://spark-api-open.xf-yun.com/v1
    llm_base_url: str = ""
    llm_api_key: str = ""
    llm_model: str = "generalv3.5"
    llm_timeout_seconds: float = 30.0
    llm_max_tokens: int = 2048
    llm_temperature: float = 0.7

    # 星火多模态（Vision）OpenAI 兼容端点：https://spark-api-open.xf-yun.com/v1
    vision_base_url: str = ""
    vision_api_key: str = ""
    vision_model: str = "4.0VImage"

    # ---------- Milvus ----------
    milvus_host: str = "milvus"
    milvus_port: int = 19530
    milvus_collection: str = "zhiyu_textbook"
    milvus_vector_dim: int = 1024  # 星火 embedding v1 维度

    # ---------- Embedding 服务（OpenAI 兼容）----------
    embedding_base_url: str = ""
    embedding_api_key: str = ""
    embedding_model: str = "embedding-v1"

    # ---------- Redis（用于 SSE 任务追踪，可选）----------
    redis_host: str = "redis"
    redis_port: int = 6379
    redis_password: str = ""
    redis_db: int = 0

    # ---------- 内部 token（与 Java 后端 zhiyu.ai.internal-token 对齐）----------
    internal_token: str = "dev-internal-token"

    # ---------- 业务中台回调地址 ----------
    backend_callback_url: str = "http://backend:8080"

    # ---------- 降级开关 ----------
    enable_llm_fallback: bool = True  # LLM 不可用时返回规则文案
    enable_milvus_fallback: bool = True  # Milvus 不可用时用内存索引

    @property
    def llm_configured(self) -> bool:
        return bool(self.llm_base_url and self.llm_api_key)

    @property
    def vision_configured(self) -> bool:
        return bool(self.vision_base_url and self.vision_api_key)

    @property
    def embedding_configured(self) -> bool:
        return bool(self.embedding_base_url and self.embedding_api_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
