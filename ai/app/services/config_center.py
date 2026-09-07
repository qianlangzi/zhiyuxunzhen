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
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from logging import INFO, WARNING
from typing import Any

import httpx

from app.core.config import settings
from app.core.logging import get_logger, log_event

logger = get_logger(__name__)

_ACTIVE_PROMPT_URL = "/api/internal/prompt/active"
_ACTIVE_AGENT_URL = "/api/internal/agent/active"
_ACTIVE_RUNTIME_URL = "/api/internal/runtime/active"

# Agent 策略类型：与 addApp 的 Agent 执行方式对应。
# - CODE ：代码内进出门（BaseAgent.invoke），内置默认
# - GRAPH：LangGraph 子图编排（如咨询图）
# - TOOL ：带工具调用的生成（function calling）
# - LOOP ：自主决策+循环（ReAct 类，规范扩展位，不强制启用）
STRATEGY_CODE = "CODE"
STRATEGY_GRAPH = "GRAPH"
STRATEGY_TOOL = "TOOL"
STRATEGY_LOOP = "LOOP"


@dataclass(frozen=True)
class AgentSpec:
    """一份「Agent 定义」的运行时视图。

    ``code`` 为注册键（对应业务中台 agent_config 的 code）；其余字段给出该 Agent 的
    定义：策略类型、可用工具、模型、采样与循环终止条件。纯代码内置值作为默认，
    由 ``config_center.resolve_agent_spec`` 用业务中台热配的字段覆盖生效。
    """

    code: str
    name: str = ""
    description: str = ""
    version: str = "1.0"
    strategy: str = STRATEGY_CODE
    tools: tuple[str, ...] = ()
    model: str | None = None
    temperature: float | None = None
    max_tokens: int | None = None
    # LOOP 策略的终止条件
    max_iterations: int = 3
    stop_condition: str = "satisfied"
    enabled: bool = True

def _parse_tools_config(raw: Any) -> tuple[str, ...] | None:
    """把业务中台热配的 toolsConfig 解析为启用工具名元组。

    支持两种形态：
      - dict   ：{name: enabled(bool)}，仅保留 enabled==True 的项
      - list   ：[name, ...]，全部启用；空列表合法（返回空元组）
    返回 ``None`` 表示无法识别（调用方沿用默认 tools）。
    """
    if isinstance(raw, dict):
        enabled = [k for k, v in raw.items() if v is True]
        return tuple(enabled)
    if isinstance(raw, (list, tuple)):
        return tuple(str(n) for n in raw if n)
    return None


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

    def resolve_agent_spec(self, code: str, defaults: AgentSpec) -> AgentSpec:
        """把业务中台热配的 Agent 元参数合入内置默认定义，得到运行时 AgentSpec。

        覆盖规则（DB 有值则优先，缺失回退 ``defaults``）：
          - outputPrompt / temperature / max_tokens / enabled 直接覆盖
          - toolsConfig（dict: name->enabled / 列表）→ 解析为启用工具名元组
          - strategy / maxIterations / stopCondition → 定义策略与终止条件
        不可识别字段忽略，保证兼容既有 agent_config 结构。
        """
        cfg = self.agents.get(code) or {}
        overrides: dict[str, Any] = {}

        if isinstance(cfg.get("name"), str) and cfg["name"]:
            overrides["name"] = cfg["name"]
        if isinstance(cfg.get("description"), str) and cfg["description"]:
            overrides["description"] = cfg["description"]
        version = cfg.get("version")
        if isinstance(version, (str, int)):
            overrides["version"] = str(version)
        strat = cfg.get("strategy")
        if isinstance(strat, str) and strat:
            overrides["strategy"] = strat.upper()
        model = cfg.get("model")
        if isinstance(model, str) and model:
            overrides["model"] = model
        temp = cfg.get("temperature")
        if isinstance(temp, (int, float)):
            overrides["temperature"] = float(temp)
        tokens = cfg.get("max_tokens")
        if isinstance(tokens, (int, float)):
            overrides["max_tokens"] = int(tokens)
        if isinstance(cfg.get("maxIterations"), int):
            overrides["max_iterations"] = int(cfg["maxIterations"])
        if isinstance(cfg.get("stopCondition"), str) and cfg["stopCondition"]:
            overrides["stop_condition"] = cfg["stopCondition"]
        enabled = cfg.get("enabled")
        if isinstance(enabled, bool):
            overrides["enabled"] = enabled

        tools = _parse_tools_config(cfg.get("toolsConfig"))
        if tools is not None:
            overrides["tools"] = tools

        return replace(defaults, **overrides)

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