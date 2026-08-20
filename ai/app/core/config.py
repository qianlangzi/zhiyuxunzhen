"""AI 中台全局配置

所有敏感凭证通过环境变量注入；为方便本地与容器内运行，未配置 LLM 凭证时
系统进入"降级模式"，使用规则 mock 兜底，保证链路可联调。

生产环境启动时执行严格校验：拒绝默认密钥和空 JWT。
"""
from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # ---------- 服务 ----------
    app_name: str = "zhiyu-ai"
    app_version: str = "1.0.0"
    env: Literal["dev", "test", "prod"] = Field(
        default="dev",
        validation_alias="ENV_MODE",
    )

    # ---------- 大模型（OpenAI 兼容协议）----------
    llm_base_url: str = ""
    llm_api_key: SecretStr = SecretStr("")
    llm_model: str = "generalv3.5"
    llm_timeout_seconds: float = 30.0
    llm_max_tokens: int = 2048
    llm_temperature: float = 0.7

    # 星火多模态（Vision）
    vision_base_url: str = ""
    vision_api_key: SecretStr = SecretStr("")
    vision_model: str = "4.0VImage"

    # ---------- Milvus ----------
    milvus_host: str = "milvus"
    milvus_port: int = 19530
    milvus_collection: str = "zhiyu_textbook"
    milvus_multi_collection: str = "zhiyu_multi"
    milvus_vector_dim: int = 1024

    # ---------- Embedding 服务（旧：OpenAI 兼容协议，纯文本）----------
    embedding_base_url: str = ""
    embedding_api_key: SecretStr = SecretStr("")
    embedding_model: str = "embedding-v1"

    # ---------- DashScope 多模态 Embedding（Qwen3-VL-Embedding）----------
    dashscope_api_key: SecretStr = SecretStr("")
    dashscope_base_url: str = "https://ws-z7vi5mam4d8415c8.cn-beijing.maas.aliyuncs.com/api/v1"
    dashscope_embedding_model: str = "qwen3-vl-embedding"
    dashscope_embedding_dim: int = 1024

    # ---------- MMORE PDF 处理服务 ----------
    mmore_url: str = "http://mmore:8002"

    # ---------- Redis ----------
    redis_host: str = "redis"
    redis_port: int = 6379
    redis_password: SecretStr = SecretStr("")
    redis_db: int = 0

    # ---------- 内部 token ----------
    internal_token: SecretStr = Field(
        default=SecretStr("dev-internal-token"),
        validation_alias="AI_INTERNAL_TOKEN",
    )
    ops_token: SecretStr = Field(
        default=SecretStr("dev-ops-token"),
        validation_alias="OPS_TOKEN",
    )

    # ---------- 业务中台回调地址 ----------
    backend_callback_url: str = "http://backend:8080"

    # ---------- Mobile JWT ----------
    jwt_secret: SecretStr = SecretStr("dev-only-secret-key-32chars-minimum-aaaa")

    # ---------- 降级开关 ----------
    enable_llm_fallback: bool = True
    enable_milvus_fallback: bool = True

    # ---------- CORS ----------
    cors_allowed_origins: list[str] = Field(
        default_factory=list,
        validation_alias="CORS_ALLOWED_ORIGINS",
    )
    vision_allowed_hosts: list[str] = Field(
        default_factory=list,
        validation_alias="VISION_ALLOWED_HOSTS",
    )

    # ---------- 对象存储（开发环境可使用本地目录） ----------
    object_storage_root: str = Field(
        default="./data/objects",
        validation_alias="OBJECT_STORAGE_ROOT",
    )
    object_storage_max_bytes: int = Field(
        default=50 * 1024 * 1024,
        validation_alias="OBJECT_STORAGE_MAX_BYTES",
    )

    # ---------- 连接池 ----------
    httpx_max_connections: int = 100
    httpx_keepalive_connections: int = 20
    redis_pool_size: int = 50
    milvus_thread_pool_size: int = 8

    # ---------- RAG 检索增强 ----------
    # Citation 原文片段最大字符（修复：原 500 截断导致生成上下文语义丢失）
    citation_max_chars: int = 2000
    # 入库 embedding 并发数（修复：DashScope 不支持批量，原逐条串行太慢）
    embed_concurrency: int = 8
    # BM25 内存索引规模上限，超过则 hybrid 自动降级 dense 并告警
    bm25_max_docs: int = 200_000
    # BM25 索引磁盘持久化目录（修复：原纯内存索引重启即失效、不可扩展）
    bm25_cache_dir: str = "./data/bm25_cache"
    # 查询改写：口语→医学术语规范化 + 多轮指代消解（需 LLM）
    query_rewrite_enabled: bool = True
    # 自适应迭代检索：top1 分数低于阈值时改写 query 重查一轮并融合
    iterative_search_enabled: bool = True
    iterative_score_threshold: float = 0.45
    # 生成侧多模态：命中带图 chunk 时调用 VLM 生成图述并入生成上下文
    image_caption_enabled: bool = True

    @model_validator(mode="after")
    def validate_prod(self) -> "Settings":
        """生产环境启动校验：拒绝默认密钥和空 JWT"""
        if self.env != "prod":
            return self

        # JWT 密钥校验
        jwt_val = self.jwt_secret.get_secret_value()
        if not jwt_val or jwt_val == "dev-only-secret-key-32chars-minimum-aaaa":
            raise ValueError("生产环境必须配置非默认 JWT_SECRET")

        # 内部 Token 校验
        token_val = self.internal_token.get_secret_value()
        if not token_val or token_val == "dev-internal-token":
            raise ValueError("生产环境必须配置非默认 AI_INTERNAL_TOKEN")

        ops_val = self.ops_token.get_secret_value()
        if not ops_val or ops_val == "dev-ops-token":
            raise ValueError("生产环境必须配置非默认 OPS_TOKEN")

        # CORS 校验
        if not self.cors_allowed_origins or "*" in self.cors_allowed_origins:
            raise ValueError("生产环境必须配置明确的 CORS_ALLOWED_ORIGINS，不允许通配符")

        if self.vision_configured and not self.vision_allowed_hosts:
            raise ValueError("生产环境必须配置 VISION_ALLOWED_HOSTS")

        # Current fallbacks return synthetic content and must never be accepted as
        # production AI results. A real, non-synthetic fallback needs a separate
        # provider profile and an explicit implementation.
        if self.enable_llm_fallback or self.enable_milvus_fallback:
            raise ValueError("生产环境必须关闭 LLM/Milvus fallback")

        return self

    @property
    def llm_configured(self) -> bool:
        return bool(self.llm_base_url and self.llm_api_key.get_secret_value())

    @property
    def vision_configured(self) -> bool:
        return bool(self.vision_base_url and self.vision_api_key.get_secret_value())

    @property
    def embedding_configured(self) -> bool:
        return bool(
            self.embedding_base_url and self.embedding_api_key.get_secret_value()
        )

    @property
    def dashscope_configured(self) -> bool:
        return bool(self.dashscope_api_key.get_secret_value())

    @property
    def redis_configured(self) -> bool:
        return bool(self.redis_host)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
