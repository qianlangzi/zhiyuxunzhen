"""大模型客户端（OpenAI 兼容协议）

设计：
1. 优先调用真实 LLM（星火/通义/DeepSeek/本地 vLLM 等任意 OpenAI 兼容服务）
2. 凭证未配置或调用失败时，按 enable_llm_fallback 决定是否走规则降级
3. 所有调用记录 latency、token、状态，便于审计
4. JSON 解析使用 StructuredOutputService，不再用"找首个 { 和最后 }"的 hack
"""
import asyncio
import json
import time
from collections.abc import AsyncIterator
from logging import INFO as _INFO
from logging import WARNING as _WARNING
from typing import Any

from openai import APIError, APITimeoutError, AsyncOpenAI, RateLimitError

from app.core.config import settings
from app.core.logging import get_logger, log_event
from app.services.structured_output import structured_output

logger = get_logger(__name__)


class LlmFallbackError(RuntimeError):
    """LLM 不可用且未启用降级"""


class LlmClient:
    """大模型客户端单例"""

    def __init__(self) -> None:
        self._client: AsyncOpenAI | None = None
        if settings.llm_configured:
            self._client = AsyncOpenAI(
                base_url=settings.llm_base_url,
                api_key=settings.llm_api_key.get_secret_value(),
                timeout=settings.llm_timeout_seconds,
            )

    @property
    def available(self) -> bool:
        return self._client is not None

    # ------------------- 同步完整响应 -------------------
    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        trace_id: str = "-",
    ) -> str:
        """非流式对话，返回完整文本"""
        if not self.available:
            return await self._fallback_chat(messages, trace_id)

        _chat_start = time.time()
        try:
            resp = await self._client.chat.completions.create(
                model=model or settings.llm_model,
                messages=messages,
                temperature=temperature if temperature is not None else settings.llm_temperature,
                max_tokens=max_tokens or settings.llm_max_tokens,
            )
            text = (resp.choices[0].message.content or "").strip()
            log_event(
                logger, _INFO, "llm_chat_ok",
                trace_id=trace_id,
                model=model or settings.llm_model,
                tokens=getattr(resp.usage, "total_tokens", 0),
                latency_ms=int((time.time() - _chat_start) * 1000),
            )
            return text
        except (APIError, APITimeoutError, RateLimitError) as e:
            log_event(logger, _WARNING, "llm_chat_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            await self._report_model_event("model_error", type(e).__name__, str(e))
            if settings.enable_llm_fallback:
                return await self._fallback_chat(messages, trace_id)
            raise LlmFallbackError(str(e)) from e

    # ------------------- 流式响应 -------------------
    async def stream(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        trace_id: str = "-",
    ) -> AsyncIterator[str]:
        """流式对话，按 token 增量返回文本"""
        if not self.available:
            async for piece in self._fallback_stream(messages, trace_id):
                yield piece
            return

        start = time.time()
        try:
            stream = await self._client.chat.completions.create(
                model=model or settings.llm_model,
                messages=messages,
                temperature=temperature if temperature is not None else settings.llm_temperature,
                max_tokens=max_tokens or settings.llm_max_tokens,
                stream=True,
            )
            first_token = True
            async for chunk in stream:
                if not chunk.choices:
                    continue
                delta = chunk.choices[0].delta.content
                if delta:
                    if first_token:
                        log_event(logger, _INFO, "llm_first_token",
                                  trace_id=trace_id,
                                  latency_ms=int((time.time() - start) * 1000))
                        first_token = False
                    yield delta
        except (APIError, APITimeoutError, RateLimitError) as e:
            log_event(logger, _WARNING, "llm_stream_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            await self._report_model_event("model_error", type(e).__name__, str(e))
            if settings.enable_llm_fallback:
                async for piece in self._fallback_stream(messages, trace_id):
                    yield piece
            else:
                raise LlmFallbackError(str(e)) from e

    # ------------------- JSON 结构化输出 -------------------
    async def chat_json(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        trace_id: str = "-",
    ) -> dict[str, Any]:
        """对话并解析为 JSON；解析失败时抛出 OutputSchemaInvalidError"""
        text = await self.chat(messages, model=model, trace_id=trace_id)
        return await structured_output.parse_to_dict(text, trace_id=trace_id)

    # ------------------- 工具调用（function calling） -------------------
    async def resolve_tools(
        self,
        messages: list[dict[str, str]],
        tools: list[Any],
        *,
        model: str | None = None,
        trace_id: str = "-",
        max_steps: int = 3,
    ) -> list[dict[str, Any]]:
        """对话并自动执行工具调用。

        模型返回 ``tool_calls`` 时，执行对应工具并把结果以 ``tool`` 角色
        回填到消息里，再继续请求模型，直到模型给出最终文本或达到最大轮数。

        未配置 LLM 或任何一轮调用失败时，直接返回原 messages（降级为无工具），
        保证不阻断上层流程。
        """
        if not self.available:
            return list(messages)

        work_messages: list[dict[str, Any]] = list(messages)
        tool_map = {tool.name: tool for tool in tools}
        try:
            for _ in range(max_steps):
                resp = await self._client.chat.completions.create(
                    model=model or settings.llm_model,
                    messages=work_messages,
                    temperature=settings.llm_temperature,
                    max_tokens=settings.llm_max_tokens,
                    tools=[tool.schema() for tool in tools],
                )
                msg = resp.choices[0].message
                if not getattr(msg, "tool_calls", None):
                    break
                work_messages.append(
                    {
                        "role": "assistant",
                        "content": msg.content or "",
                        "tool_calls": [
                            {
                                "id": tc.id,
                                "type": "function",
                                "function": {
                                    "name": tc.function.name,
                                    "arguments": tc.function.arguments,
                                },
                            }
                            for tc in msg.tool_calls
                        ],
                    }
                )
                for tc in msg.tool_calls:
                    tool = tool_map.get(tc.function.name)
                    if tool is None:
                        out = f"未知工具：{tc.function.name}"
                    else:
                        try:
                            args = json.loads(tc.function.arguments) if tc.function.arguments else {}
                        except json.JSONDecodeError:
                            args = {}
                        try:
                            out = await tool.run(args, trace_id=trace_id)
                        except Exception as e:  # noqa: BLE001
                            out = f"工具执行失败：{e}"
                    work_messages.append(
                        {"role": "tool", "tool_call_id": tc.id, "content": out}
                    )
        except (APIError, APITimeoutError, RateLimitError) as e:
            log_event(logger, _WARNING, "llm_tools_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            await self._report_model_event("model_error", type(e).__name__, str(e))
            return list(messages)
        return work_messages

    # ------------------- 降级实现 -------------------
    async def _fallback_chat(
        self,
        messages: list[dict[str, str]],
        trace_id: str,
    ) -> str:
        """规则降级：未配置 LLM 时根据 messages 拼装简单回复"""
        log_event(logger, _INFO, "llm_fallback_used", trace_id=trace_id)
        await self._report_model_event("degradation", "fallback", "LLM 未配置或不可用，使用规则降级")
        last_user = ""
        for m in reversed(messages):
            if m.get("role") == "user":
                last_user = m.get("content", "")[:200]
                break
        return (
            "【降级模式】当前未配置大模型 API Key，已启用规则兜底。\n"
            f"你刚才的提问是：{last_user}\n"
            "请在 .env 中配置 LLM_BASE_URL / LLM_API_KEY 后重启服务以获得真实 AI 回复。"
        )

    async def _fallback_stream(
        self,
        messages: list[dict[str, str]],
        trace_id: str,
    ) -> AsyncIterator[str]:
        """流式降级：把降级文案按字输出"""
        text = await self._fallback_chat(messages, trace_id)
        for ch in text:
            await asyncio.sleep(0.02)
            yield ch

    # ------------------- 模型事件上报 -------------------
    async def _report_model_event(self, event_type: str, model_name: str, error_msg: str) -> None:
        """LLM 异常/降级事件异步回调业务中台（失败静默，不阻塞主流程）"""
        try:
            from app.services.backend_client import backend_client  # noqa: PLC0415  # 延迟导入避免循环依赖
            await backend_client.log_model_event(
                event_type=event_type,
                model_name=model_name,
                error_message=error_msg,
                detail={"fallback": settings.enable_llm_fallback},
            )
        except Exception as e:  # noqa: BLE001
            logger.warning("model_event 上报失败: %s", e)


# 模块级单例
llm_client = LlmClient()
