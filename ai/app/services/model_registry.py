"""模型注册表：从业务中台拉取「启用且激活」的模型配置并热同步进 settings

设计（对应管理端「模型管理」模块，参照 ccswitch 供应商管理思路）：

- AI 中台启动后周期调用业务中台 ``GET /api/internal/model/active``，
  拿到每个能力维度当前激活的模型真实配置（base_url / api_key / model / 维度 / 超时 / 温度）。
- 将数据源配置逐项覆盖到 ``settings.*_*``（LLM / VISION / EMBEDDING / EMBEDDING_MULTI）。
  由于既有调用点多直接读取 settings（如 vision、hybrid_retrieval 等每次请求构建客户端），
  覆盖 settings 即可让所有调用点统一生效，实现「管理端一键切换 → 热生效，无需重启 AI 服务」。
- 依赖启动期快照的常驻客户端（LlmClient / RagService）通过各自 ``rebuild()`` 按新 settings 重建。
- 数据源未配置某能力时，保留 .env 原值作为回退基线，平滑迁移。

安全：走内网信任边界（X-Internal-Token 鉴权），返回明文密钥仅供 AI 中台内部使用，不对外暴露。
"""
import asyncio
import hashlib
import httpx
import json
from datetime import datetime, timezone
from logging import INFO, WARNING
from pydantic import SecretStr

from app.core.config import settings
from app.core.logging import get_logger, log_event

logger = get_logger(__name__)

_ACTIVE_URL = "/api/internal/model/active"


class ModelRegistry:
    """模型注册表单例：启动拉取一次 + 周期刷新"""

    # 能力维度常量（与后端 ai_model.capability 对齐）
    CAP_LLM = "LLM"
    CAP_VISION = "VISION"
    CAP_EMBEDDING = "EMBEDDING"
    CAP_EMBEDDING_MULTI = "EMBEDDING_MULTI"

    def __init__(self) -> None:
        base = settings.backend_callback_url.rstrip("/")
        self._base_url = base
        self._client: httpx.AsyncClient | None = None
        self._latest: dict[str, dict] = {}
        self._task: asyncio.Task | None = None
        self._baseline = self._capture_baseline()
        self._version: str | None = None
        self._last_refresh_at: str | None = None
        self._last_error: str | None = None

    @staticmethod
    def _capture_baseline() -> dict[str, object]:
        """Capture deployment configuration so DB deactivation can really roll back."""
        return {
            "LLM": {
                "base_url": settings.llm_base_url,
                "api_key": settings.llm_api_key,
                "model": settings.llm_model,
                "timeout_seconds": settings.llm_timeout_seconds,
                "max_tokens": settings.llm_max_tokens,
                "temperature": settings.llm_temperature,
            },
            "VISION": {
                "base_url": settings.vision_base_url,
                "api_key": settings.vision_api_key,
                "model": settings.vision_model,
            },
            "EMBEDDING": {
                "base_url": settings.embedding_base_url,
                "api_key": settings.embedding_api_key,
                "model": settings.embedding_model,
            },
            "EMBEDDING_MULTI": {
                "base_url": settings.dashscope_base_url,
                "api_key": settings.dashscope_api_key,
                "model": settings.dashscope_embedding_model,
                "dimension": settings.dashscope_embedding_dim,
            },
        }

    # ---------------- 生命周期 ----------------

    def start(self) -> None:
        """启动后台刷新循环（幂等，已启动则不重复创建）"""
        if self._task is not None and not self._task.done():
            return
        self._task = asyncio.create_task(
            self._run_loop(), name="model-registry-refresh"
        )

    async def stop(self) -> None:
        """停止刷新循环并关闭 HTTP 客户端"""
        if self._task is not None and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                pass
            self._task = None
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    # ---------------- 内部实现 ----------------

    def _get_client(self) -> httpx.AsyncClient:
        """惰性创建带内网鉴权头的客户端（复用，避免每次新建连接池）"""
        if self._client is None:
            self._client = httpx.AsyncClient(
                timeout=httpx.Timeout(6.0, connect=3.0),
                base_url=self._base_url,
                headers={
                    "X-Internal-Token": settings.internal_token.get_secret_value()
                },
            )
        return self._client

    async def _run_loop(self) -> None:
        interval = max(settings.model_config_ttl_seconds, 5.0)
        # 启动立即刷新一次，避免冷启动期间用旧配置
        await self.refresh()
        while True:
            await asyncio.sleep(interval)
            await self.refresh()

    async def refresh(self) -> None:
        """拉取活跃模型配置并同步进 settings，失败静默（保留上次快照或 .env 基线）"""
        try:
            payload = await self._fetch()
            self._apply(payload)
            self._latest = payload
            log_event(logger, INFO, "model_registry_refreshed",
                      count=len(payload))
            # 重建依赖启动期快照的常驻客户端，使新配置当日生效
            self._rebuild_cached_clients()
        except Exception as e:  # noqa: BLE001
            self._last_error = f"{type(e).__name__}: {e}"[:300]
            log_event(logger, WARNING, "model_registry_refresh_error",
                      error=type(e).__name__, msg=str(e))

    async def _fetch(self) -> dict[str, dict]:
        client = self._get_client()
        resp = await client.get(_ACTIVE_URL)
        resp.raise_for_status()
        body = resp.json()
        if body.get("code") != 0:
            raise RuntimeError(f"业务中台返回非成功: code={body.get('code')}")
        return body.get("data") or {}

    def _apply(self, payload: dict[str, dict]) -> None:
        # Reset every capability first. An empty/removed active row must not leave
        # the previous provider in memory and silently keep serving traffic.
        self._restore_baseline()
        for cap, cfg in payload.items():
            self._apply_one(cap, cfg)

        encoded = json.dumps(payload, sort_keys=True, ensure_ascii=True, separators=(",", ":"))
        self._version = hashlib.sha256(encoded.encode("utf-8")).hexdigest()[:16]
        self._last_refresh_at = datetime.now(timezone.utc).isoformat()
        self._last_error = None

    def _restore_baseline(self) -> None:
        for cap, cfg in self._baseline.items():
            # Baseline is captured from Settings and intentionally kept private;
            # values are restored atomically before applying the active snapshot.
            assert isinstance(cfg, dict)
            if cap == self.CAP_LLM:
                settings.llm_base_url = cfg["base_url"]
                settings.llm_api_key = cfg["api_key"]
                settings.llm_model = cfg["model"]
                settings.llm_timeout_seconds = cfg["timeout_seconds"]
                settings.llm_max_tokens = cfg["max_tokens"]
                settings.llm_temperature = cfg["temperature"]
            elif cap == self.CAP_VISION:
                settings.vision_base_url = cfg["base_url"]
                settings.vision_api_key = cfg["api_key"]
                settings.vision_model = cfg["model"]
            elif cap == self.CAP_EMBEDDING:
                settings.embedding_base_url = cfg["base_url"]
                settings.embedding_api_key = cfg["api_key"]
                settings.embedding_model = cfg["model"]
            elif cap == self.CAP_EMBEDDING_MULTI:
                settings.dashscope_base_url = cfg["base_url"]
                settings.dashscope_api_key = cfg["api_key"]
                settings.dashscope_embedding_model = cfg["model"]
                settings.dashscope_embedding_dim = cfg["dimension"]

    def _apply_one(self, cap: str, cfg: dict) -> None:
        # 后端 ActiveModelVO 默认 Jackson 序列化为 camelCase
        api_key = str(cfg.get("apiKey") or "")
        base_url = str(cfg.get("baseUrl") or "").rstrip("/")
        model = str(cfg.get("model") or "")
        if not base_url or not model:
            return

        if cap == self.CAP_LLM:
            settings.llm_base_url = base_url
            if api_key:
                settings.llm_api_key = SecretStr(api_key)
            settings.llm_model = model
            if cfg.get("timeoutSeconds"):
                settings.llm_timeout_seconds = float(cfg["timeoutSeconds"])
            if cfg.get("maxTokens"):
                settings.llm_max_tokens = int(cfg["maxTokens"])
            if cfg.get("temperature") is not None:
                settings.llm_temperature = float(cfg["temperature"])
        elif cap == self.CAP_VISION:
            settings.vision_base_url = base_url
            if api_key:
                settings.vision_api_key = SecretStr(api_key)
            settings.vision_model = model
        elif cap == self.CAP_EMBEDDING:
            settings.embedding_base_url = base_url
            if api_key:
                settings.embedding_api_key = SecretStr(api_key)
            settings.embedding_model = model
        elif cap == self.CAP_EMBEDDING_MULTI:
            settings.dashscope_base_url = base_url
            if api_key:
                settings.dashscope_api_key = SecretStr(api_key)
            settings.dashscope_embedding_model = model
            if cfg.get("dimension"):
                settings.dashscope_embedding_dim = int(cfg["dimension"])

    def _rebuild_cached_clients(self) -> None:
        """常驻客户端按新 settings 重建（延迟导入避免循环依赖）"""
        from app.services.llm_client import llm_client
        from app.services.rag_service import rag_service

        llm_client.rebuild()
        rag_service.rebuild()

    # ---------------- 对外查询 ----------------

    @property
    def latest(self) -> dict[str, dict]:
        """最近一次成功拉取的活跃模型快照（仅用于观测/调试）"""
        return self._latest

    def status_summary(self) -> dict[str, object]:
        return {
            "version": self._version,
            "last_refresh_at": self._last_refresh_at,
            "last_error": self._last_error,
            "capabilities": sorted(self._latest),
            "count": len(self._latest),
            "refresh_interval_seconds": max(float(settings.model_config_ttl_seconds), 5.0),
        }


# 模块级单例
model_registry = ModelRegistry()
