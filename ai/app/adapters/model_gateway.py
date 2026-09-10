"""模型网关适配层。

业务工作流只依赖这个稳定接口，不直接依赖 OpenAI SDK 或具体供应商。
"""
import asyncio
from collections.abc import AsyncIterator
from typing import Any

from app.services.config_center import (
    STRATEGY_LOOP,
    STRATEGY_TOOL,
    AgentSpec,
    config_center,
)
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
        temperature: float | None = None,
        max_tokens: int | None = None,
        # 与 LlmClient.chat_json 保持一致：结构化输出默认关闭思维链。
        # 网关层必须与下层默认值同步，否则网关的 False 会覆盖下层的 True。
        disable_thinking: bool = True,
        trace_id: str = "-",
    ) -> dict[str, Any]:
        return await self._client.chat_json(
            messages,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            disable_thinking=disable_thinking,
            trace_id=trace_id,
        )

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

    async def maybe_ground_tools(
        self,
        messages: list[dict[str, Any]],
        agent_code: str,
        tools: list[Any],
        *,
        trace_id: str = "-",
        stream: bool = False,
    ) -> list[dict[str, Any]]:
        """配置驱动的检索增强预置（best-effort，时间盒约束）。

        仅当该 Agent 被管理端配置为 ``TOOL``/``LOOP`` 策略 **且** 其 toolsConfig 开启
        ``rag``（即 search_textbook 真正可用）时，才会在生成前先跑一轮工具调用，把教材
        检索结果回填进消息上下文。否则原样返回 ``messages``——与现状完全一致，默认零行为变更。

        硬时间盒：``stream=True``（学伴流式，首字延迟敏感）预算更短；超时/异常一律返回
        原始消息，不阻塞、不报错，保证用户等待时间可控。
        """
        spec = config_center.resolve_agent_spec(agent_code, AgentSpec(code=agent_code))
        if spec.strategy not in (STRATEGY_TOOL, STRATEGY_LOOP):
            return messages
        if not self._filter_tools_by_config(agent_code, list(tools)):
            # 管理端未在 toolsConfig 开启 rag，不引入额外的 LLM 决策轮次
            return messages
        budget = 2.5 if stream else 6.0
        try:
            return await asyncio.wait_for(
                self.resolve_tools(
                    messages,
                    list(tools),
                    agent_code=agent_code,
                    trace_id=trace_id,
                    max_steps=spec.max_iterations or 1,
                ),
                timeout=budget,
            )
        except Exception:  # noqa: BLE001 - 检索增强失败不影响主链路
            return list(messages)

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
