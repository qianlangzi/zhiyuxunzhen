"""模型网关适配层。

业务工作流只依赖这个稳定接口，不直接依赖 OpenAI SDK 或具体供应商。
"""
from collections.abc import AsyncIterator
from typing import Any

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
        trace_id: str = "-",
    ) -> AsyncIterator[str]:
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
        trace_id: str = "-",
        max_steps: int = 3,
    ) -> list[dict[str, Any]]:
        return await self._client.resolve_tools(
            messages,
            tools,
            model=model,
            trace_id=trace_id,
            max_steps=max_steps,
        )


model_gateway = ModelGateway()
