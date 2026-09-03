"""模型网关适配层。

业务工作流只依赖这个稳定接口，不直接依赖 OpenAI SDK 或具体供应商。
"""
from collections.abc import AsyncIterator
from typing import Any

from app.services.config_center import config_center
from app.services.llm_client import LlmClient, llm_client


class ModelGateway:
    def __init__(self, client: LlmClient | None = None) -> None:
        self._client = client or llm_client

    @property
    def available(self) -> bool:
        return self._client.available

    async def stream(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        agent_code: str | None = None,
        trace_id: str = "-",
    ) -> AsyncIterator[str]:
        temperature, max_tokens = self._apply_agent_sampling(
            agent_code, temperature, max_tokens
        )
        async for delta in self._client.stream(
            messages,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            trace_id=trace_id,
        ):
            yield delta

    async def chat_json(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        trace_id: str = "-",
    ) -> dict[str, Any]:
        return await self._client.chat_json(messages, model=model, trace_id=trace_id)

    async def resolve_tools(
        self,
        messages: list[dict[str, str]],
        tools: list[Any],
        *,
        model: str | None = None,
        agent_code: str | None = None,
        trace_id: str = "-",
        max_steps: int = 3,
    ) -> list[dict[str, Any]]:
        enabled = self._filter_tools_by_config(agent_code, tools)
        return await self._client.resolve_tools(
            messages,
            enabled,
            model=model,
            trace_id=trace_id,
            max_steps=max_steps,
        )

    # 各工具由哪些 tools_config 标签启用：config 命中任一标签即保留该工具
    # 例：tools_config="rag,vision" → search_textbook（rag）被启用
    _TOOL_ENABLED_BY_TAG: dict[str, set[str]] = {
        "search_textbook": {"rag"},
    }

    def _filter_tools_by_config(
        self, agent_code: str | None, tools: list[Any]
    ) -> list[Any]:
        """按 AI 配置中心 Agent 的 tools_config 过滤可调用工具，让管理端工具开关真正生效。

        - tools_config 为空/未配置 → 保留全部传入工具（向后兼容，原行为不变）
        - 含 none            → 全部禁用（显式关闭工具调用）
        - 含 rag / vision 等标签 → 仅保留被任一标签启用的工具
        """
        if not agent_code or not tools:
            return tools
        agent = config_center.get_agent(agent_code)
        raw = (agent or {}).get("toolsConfig") or ""
        tags = {t.strip().lower() for t in raw.split(",") if t.strip()}
        if not tags or "all" in tags:
            return tools
        if "none" in tags:
            return []
        return [
            t for t in tools if any(
                t.name in self._TOOL_ENABLED_BY_TAG.get(tag, set())
                for tag in tags
            )
        ]

    def _apply_agent_sampling(
        self,
        agent_code: str | None,
        temperature: float | None,
        max_tokens: int | None,
    ) -> tuple[float | None, int | None]:
        """集中采样覆盖：当管理端对某 agent_code 配置了 temperature/max_tokens，
        统一覆盖本次请求，保证「Agent 行为元参数」热改对编辑型 Agent 全局生效。"""
        if not agent_code:
            return temperature, max_tokens
        agent = config_center.get_agent(agent_code)
        if agent:
            temp = agent.get("temperature")
            tokens = agent.get("max_tokens")
            if temp is not None:
                temperature = float(temp)
            if tokens:
                max_tokens = int(tokens)
        return temperature, max_tokens


model_gateway = ModelGateway()
