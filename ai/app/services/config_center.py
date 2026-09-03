"""AI 配置中心注册表：从业务中台热同步「提示词 / Agent 元参数 / RAG 运行参数」

与 ModelRegistry（模型连接参数）互补，共同实现管理端「AI 配置中心」的热更新闭环：

- 提示词   ：周期拉取 ``GET /api/internal/prompt/active`` → 内存 dict[name -> content]，
             业务代码通过 ``get_prompt(name)`` 读取；未配置的 name 回退内置模板。
- Agent    ：周期拉取 ``GET /api/internal/agent/active`` → 内存 dict[code -> params]，
             提供 system prompt 解析（优先 agent.prompt_override，其次引用的提示词，
             最后内置模板）与采样参数（temperature/max_tokens）与工具声明。
- RAG 参数 ：周期拉取 ``GET /api/internal/runtime/active`` → 覆盖 settings 中对应的
             运行参数（检索/改写/迭代/图述等）。每次拉取先重置为该组键的内置基线，
             再应用业务中台最新值，删除键即可恢复默认（幂等、可回滚）。

安全：走内网信任边界（X-Internal-Token 鉴权），仅在 AI 中台内部读取。
"""
import asyncio
from datetime import datetime, timezone
import httpx
from logging import INFO, WARNING
from typing import Any

from app.core.config import settings
from app.core.logging import get_logger, log_event

logger = get_logger(__name__)

_ACTIVE_PROMPT_URL = "/api/internal/prompt/active"
_ACTIVE_AGENT_URL = "/api/internal/agent/active"
_ACTIVE_RUNTIME_URL = "/api/internal/runtime/active"

# ---------------------------------------------------------------------------
# 可被业务中台热覆盖的 RAG 运行参数（settings 属性名 == 数据库 config_key）
# 每次拉取先重置为企业基线的 .env 值，再应用 DB 最新值，支持一键回滚默认。
# ---------------------------------------------------------------------------
# attr -> 类型（用于取值转换）
_RUNTIME_SETTINGS_KEYS: dict[str, str] = {
    "citation_max_chars": "int",
    "embed_concurrency": "int",
    "bm25_max_docs": "int",
    "query_rewrite_enabled": "bool",
    "iterative_search_enabled": "bool",
    "iterative_score_threshold": "float",
    "image_caption_enabled": "bool",
    "live_mentor_hint_enabled": "bool",
    "rag_top_k": "int",
    "rag_strategy": "str",
}


class ConfigCenter:
    """提示词 / Agent / RAG 参数热同步注册表单例"""

    def __init__(self) -> None:
        base = settings.backend_callback_url.rstrip("/")
        self._base_url = base
        self._client: httpx.AsyncClient | None = None
        self._task: asyncio.Task | None = None

        # 提示词：name -> content（已格式化占位由调用方处理）
        self.prompts: dict[str, str] = {}
        # Agent：code -> {promptName, promptOverride, temperature, maxTokens, toolsConfig}
        self.agents: dict[str, dict[str, Any]] = {}
        # RAG 运行参数覆盖：key -> value（字符串，应用时按类型转换）
        self.runtime_overrides: dict[str, str] = {}

        # RAG 参数的内置基线：启动时（.env）的值，用于每次拉取前重置
        self._runtime_baseline: dict[str, Any] = {
            k: getattr(settings, k) for k in _RUNTIME_SETTINGS_KEYS
        }

        # 运行态追踪：各类别最近刷新时间（UTC iso）与最近一次错误 msg
        self._last_refresh: dict[str, str] = {}
        self._last_errors: dict[str, str] = {}

    # ---------------- 生命周期 ----------------

    def start(self) -> None:
        if self._task is not None and not self._task.done():
            return
        self._task = asyncio.create_task(self._run_loop(), name="config-center-refresh")

    async def stop(self) -> None:
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

    def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                timeout=httpx.Timeout(6.0, connect=3.0),
                base_url=self._base_url,
                headers={"X-Internal-Token": settings.internal_token.get_secret_value()},
            )
        return self._client

    async def _run_loop(self) -> None:
        interval = max(settings.model_config_ttl_seconds, 5.0)
        await self.refresh()
        while True:
            await asyncio.sleep(interval)
            await self.refresh()

    async def refresh(self) -> None:
        """拉取三类活跃配置进内存；失败静默（保留上次快照），不影响在线服务"""
        for label, url, handler in (
            ("prompt", _ACTIVE_PROMPT_URL, self._apply_prompts),
            ("agent", _ACTIVE_AGENT_URL, self._apply_agents),
            ("runtime", _ACTIVE_RUNTIME_URL, self._apply_runtime),
        ):
            try:
                payload = await self._fetch(url)
                handler(payload)
                self._last_refresh[label] = datetime.now(timezone.utc).isoformat()
                self._last_errors.pop(label, None)
                log_event(logger, INFO, f"config_center_{label}_refreshed",
                          count=len(payload))
            except Exception as e:  # noqa: BLE001
                self._last_errors[label] = str(e)[:300]
                log_event(logger, WARNING, f"config_center_{label}_refresh_error",
                          error=type(e).__name__, msg=str(e))

    async def _fetch(self, url: str) -> dict:
        client = self._get_client()
        resp = await client.get(url)
        resp.raise_for_status()
        body = resp.json()
        if body.get("code") != 0:
            raise RuntimeError(f"业务中台返回非成功: code={body.get('code')}")
        return body.get("data") or {}

    # ---------------- 应用 ---------------

    def _apply_prompts(self, payload: dict) -> None:
        # payload: {name: {"content":..., "version":..., "id":...}}
        self.prompts = {
            name: str(cfg.get("content") or "")
            for name, cfg in payload.items()
        }

    def _apply_agents(self, payload: dict) -> None:
        # payload: {code: {"promptName":..., "promptOverride":..., ...}}
        self.agents = {code: dict(cfg) for code, cfg in payload.items()}

    def _apply_runtime(self, payload: dict) -> None:
        # 先重置为该组键内置基线，再应用 DB 最新值 → 删除键即可回滚默认
        for attr, typ in _RUNTIME_SETTINGS_KEYS.items():
            self._set_typed(attr, self._runtime_baseline[attr], typ)
        applied: dict[str, str] = {}
        for key, raw in payload.items():
            if key not in _RUNTIME_SETTINGS_KEYS:
                continue
            typ = _RUNTIME_SETTINGS_KEYS[key]
            try:
                self._set_typed(key, raw, typ)
                applied[key] = str(raw)
            except (TypeError, ValueError) as e:
                log_event(logger, WARNING, "config_center_runtime_invalid",
                          key=key, raw=raw, error=str(e))
        self.runtime_overrides = applied

    @staticmethod
    def _set_typed(attr: str, raw: Any, typ: str) -> None:
        if typ == "int":
            setattr(settings, attr, int(raw))
        elif typ == "float":
            setattr(settings, attr, float(raw))
        elif typ == "bool":
            val = str(raw).strip().lower()
            if val not in ("true", "false"):
                raise ValueError(f"invalid bool: {raw}")
            setattr(settings, attr, val == "true")
        else:
            setattr(settings, attr, str(raw))

    # ---------------- 对外查询 ----------------

    def get_prompt(self, name: str) -> str | None:
        """返回业务中台配置的提示词正文稿，未配置返回 None（调用方回退内置模板）"""
        return self.prompts.get(name)

    def get_agent(self, code: str) -> dict[str, Any] | None:
        return self.agents.get(code)

    def resolve_system_prompt(
        self,
        agent_code: str,
        fallback_prompt_name: str,
        default: str,
        **kwargs: Any,
    ) -> str:
        """解析一个 Agent 的 system prompt 正文（不含安全尾部）：
        1. agent.prompt_override（直接覆盖）
        2. agent.prompt_name 命中的提示词
        3. fallback_prompt_name 命中的提示词
        4. 内置 default
        支持 {kwargs} 占位；格式化失败回退内置。
        """
        agent = self.agents.get(agent_code) or {}
        source: str | None = agent.get("promptOverride") or None
        prompt_name = agent.get("promptName") or fallback_prompt_name
        if not source:
            source = self.prompts.get(prompt_name)
        if not source:
            source = self.prompts.get(fallback_prompt_name)
        if source:
            try:
                return source.format(**kwargs) if kwargs else source
            except Exception as e:  # noqa: BLE001
                log_event(logger, WARNING, "config_center_prompt_format_fallback",
                          agent=agent_code, error=str(e)[:200])
                return default
        return default

    def agent_sampling(
        self, agent_code: str, default_temp: float, default_max_tokens: int
    ) -> tuple[float, int]:
        """返回该 Agent 的 (temperature, max_tokens) 覆盖；未配置返回全局默认"""
        agent = self.agents.get(agent_code)
        if not agent:
            return default_temp, default_max_tokens
        temp = agent.get("temperature")
        tokens = agent.get("max_tokens")
        return (
            float(temp) if temp is not None else default_temp,
            int(tokens) if tokens else default_max_tokens,
        )

    # ---------------- 运行态 / 生效来源（仅供管理端 status 查询） ----------------

    def get_effective_prompt_source(self, name: str) -> str:
        """返回 name 当前生效来源：'database'（DB 热改生效）/ 'built-in'（内置回退中）"""
        return "database" if name in self.prompts else "built-in"

    def get_effective_agent_source(self, code: str) -> str:
        return "database" if code in self.agents else "built-in"

    def status_summary(self) -> dict[str, Any]:
        """面向管理端运行态页：各类别刷新时间/数量/错误、生效来源、RAG 生效值"""
        return {
            "last_refresh": dict(self._last_refresh),
            "last_errors": dict(self._last_errors),
            "prompt_count": len(self.prompts),
            "agent_count": len(self.agents),
            "runtime_count": len(self.runtime_overrides),
            "runtime_effective": {
                key: {
                    "value": getattr(settings, key),
                    "baseline": self._runtime_baseline[key],
                    "source": "database" if key in self.runtime_overrides else "baseline",
                }
                for key in _RUNTIME_SETTINGS_KEYS
            },
        }


# 模块级单例
config_center = ConfigCenter()


# 便捷别名，供 prompts/templates.py 与各 Agent 使用
def get_prompt(name: str) -> str | None:
    return config_center.get_prompt(name)