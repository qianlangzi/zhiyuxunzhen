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
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
        protected_namespaces=(),
    )

    # ---------- 服务 ----------
    app_name: str = "zhiyu-ai"
    app_version: str = "1.0.0"
    env: Literal["dev", "test", "prod"] = Field(
        default="dev",
        validation_alias="ENV_MODE",
    )

    # ---------- 大模型（OpenAI 兼容协议）----------
    # 运行期模型切换由 ModelRegistry 从业务中台 ai_model 表热同步覆盖以下 *_ 字段；
    # .env 中的值作为数据源未配置该能力时的回退基线，平滑迁移无需一次性补齐。
    llm_base_url: str = ""
    llm_api_key: SecretStr = SecretStr("")
    llm_model: str = "generalv3.5"
    llm_timeout_seconds: float = 30.0
    llm_max_tokens: int = 2048
    llm_temperature: float = 0.7

    # 模型注册表刷新间隔（秒）：从业务中台拉取「启用且激活」模型配置，实现无重启热切换
    model_config_ttl_seconds: float = 30.0

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
    dashscope_base_url: str = ""
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
    # AI 端使用独立的 AI_CORS_ALLOWED_ORIGINS（JSON 数组格式，如 ["https://admin.example.com"]）
    # 与 Java 端的 CORS_ALLOWED_ORIGINS（逗号分隔字符串）隔离，避免格式冲突
    cors_allowed_origins: list[str] = Field(
        default_factory=list,
        validation_alias="AI_CORS_ALLOWED_ORIGINS",
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
    # 问诊流实时导师提示（思维树 + 苏格拉底提示）总闸。
    # 默认关闭：训练态不向学生实时推送思维树/漏诊提示（会剧透诊断、削弱问诊训练）；
    # 复盘思维树由结束时 evaluator 一并产出。管理端运行时配置可热开（教学演示等场景）。
    live_mentor_hint_enabled: bool = False
    # 检索默认命中数（解决 tutor/workflow 硬编码 top_k）
    rag_top_k: int = 5
    # 检索默认策略：dense / sparse / hybrid / rerank（解决 tutor/workflow 硬编码 strategy）
    rag_strategy: str = "hybrid"

    @model_validator(mode="after")
    def validate_prod(self) -> "Settings":
        """生产环境启动校验：拒绝默认密钥、弱密钥和空 JWT"""
        if self.env != "prod":
            return self

        # 历史代码/配置中出现过的公开占位密钥，生产环境一律拒绝
        known_placeholder_secrets = {
            "dev-only-secret-key-32chars-minimum-aaaa",
            "please-change-me-to-a-random-32-char-string",
            "test-secret-key-32chars-minimum-aaaa",
        }

        # JWT 密钥校验：非空、非公开占位值、至少 32 字节（UTF-8，与 Java JwtUtils.init 对齐）
        jwt_val = self.jwt_secret.get_secret_value()
        if not jwt_val or jwt_val in known_placeholder_secrets:
            raise ValueError("生产环境必须配置非默认 JWT_SECRET，禁止使用公开占位密钥")
        jwt_bytes = len(jwt_val.encode("utf-8"))
        if jwt_bytes < 32:
            raise ValueError(
                f"生产环境 JWT_SECRET 至少 32 字节(UTF-8)，当前仅 {jwt_bytes} 字节"
            )

        # 内部 Token 校验：非空、非默认值、至少 32 字节（UTF-8，防弱 token 被暴力猜测）
        token_val = self.internal_token.get_secret_value()
        if not token_val or token_val == "dev-internal-token":
            raise ValueError("生产环境必须配置非默认 AI_INTERNAL_TOKEN")
        token_bytes = len(token_val.encode("utf-8"))
        if token_bytes < 32:
            raise ValueError(
                f"生产环境 AI_INTERNAL_TOKEN 至少 32 字节(UTF-8)，当前仅 {token_bytes} 字节"
            )

        ops_val = self.ops_token.get_secret_value()
        if not ops_val or ops_val == "dev-ops-token":
            raise ValueError("生产环境必须配置非默认 OPS_TOKEN")
        ops_bytes = len(ops_val.encode("utf-8"))
        if ops_bytes < 32:
            raise ValueError(
                f"生产环境 OPS_TOKEN 至少 32 字节(UTF-8)，当前仅 {ops_bytes} 字节"
            )

        # CORS 校验
        if not self.cors_allowed_origins or "*" in self.cors_allowed_origins:
            raise ValueError("生产环境必须配置明确的 AI_CORS_ALLOWED_ORIGINS，不允许通配符")

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
