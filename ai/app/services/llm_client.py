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

# 管理端可见的业务文案（不含异常堆栈 / 密钥 / 请求体）
friendly_degradation = "LLM 未配置或暂不可用，已启用规则降级"
friendly_timeout = "模型请求超时"
friendly_error = "模型调用失败，请前往管理端检查模型配置"
friendly_recovered = "模型恢复正常，已结束降级/异常状态"


class LlmFallbackError(RuntimeError):
    """LLM 不可用且未启用降级"""


class LlmClient:
    """大模型客户端单例"""

    def __init__(self) -> None:
        self._client: AsyncOpenAI | None = None
        # 健康态跟踪：用于产生「恢复」事件，避免每次异常重复上报
        self._degraded = False          # 是否处于规则降级态
        self._failed_models: set[str] = set()  # 有未恢复错误/超时的模型集合
        if settings.llm_configured:
            self._client = AsyncOpenAI(
                base_url=settings.llm_base_url,
                api_key=settings.llm_api_key.get_secret_value(),
                timeout=settings.llm_timeout_seconds,
            )

    @property
    def available(self) -> bool:
        return self._client is not None

    def rebuild(self) -> None:
        """按当前 settings 重建客户端（供 ModelRegistry 热切换模型时调用）
        保留健康态标记：若从降级/失败中恢复，下一次成功调用会补上「恢复」事件。
        """
        if settings.llm_configured:
            self._client = AsyncOpenAI(
                base_url=settings.llm_base_url,
                api_key=settings.llm_api_key.get_secret_value(),
                timeout=settings.llm_timeout_seconds,
            )
        else:
            self._client = None

    # ------------------- 同步完整响应 -------------------
    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        trace_id: str = "-",
        scene: str = "unknown",
    ) -> str:
        """非流式对话，返回完整文本

        scene: 调用场景标识（chat/review/lesson/case...），用于管理端 Token 用量按场景归类
        """
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
            latency_ms = int((time.time() - _chat_start) * 1000)
            log_event(
                logger, _INFO, "llm_chat_ok",
                trace_id=trace_id,
                model=model or settings.llm_model,
                tokens=getattr(resp.usage, "total_tokens", 0),
                latency_ms=latency_ms,
            )
            # 上报用量供管理端 Token 管理统计（此前 token 只进日志，管理端看不到）
            await self._report_usage(
                model=model, usage=getattr(resp, "usage", None),
                latency_ms=latency_ms, trace_id=trace_id, scene=scene, is_stream=False,
            )
            await self._maybe_report_recovery(model, trace_id)
            return text
        except (APIError, APITimeoutError, RateLimitError) as e:
            log_event(logger, _WARNING, "llm_chat_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e)[:300])
            event_type = "timeout" if isinstance(e, APITimeoutError) else "model_error"
            await self._handle_model_failure(event_type, model, trace_id)
            if settings.enable_llm_fallback:
                return await self._fallback_chat(messages, trace_id)
            raise LlmFallbackError(friendly_timeout if isinstance(e, APITimeoutError) else str(e)) from e

    # ------------------- 流式响应 -------------------
    async def stream(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
        trace_id: str = "-",
        scene: str = "unknown",
    ) -> AsyncIterator[str]:
        """流式对话，按 token 增量返回文本

        scene: 调用场景标识，用于管理端 Token 用量按场景归类
        """
        if not self.available:
            async for piece in self._fallback_stream(messages, trace_id):
                yield piece
            return

        start = time.time()
        usage: Any = None
        try:
            stream = await self._create_stream(model, messages, temperature, max_tokens)
            first_token = True
            recovered_reported = False
            async for chunk in stream:
                # 开启 stream_options 后，兼容服务会在最后一个 chunk（choices 为空）携带 usage
                chunk_usage = getattr(chunk, "usage", None)
                if chunk_usage is not None:
                    usage = chunk_usage
                if not chunk.choices:
                    continue
                delta = chunk.choices[0].delta.content
                if delta:
                    if first_token:
                        log_event(logger, _INFO, "llm_first_token",
                                  trace_id=trace_id,
                                  latency_ms=int((time.time() - start) * 1000))
                        first_token = False
                        if not recovered_reported:
                            await self._maybe_report_recovery(model, trace_id)
                            recovered_reported = True
                    yield delta
            # 流正常结束后上报用量（用量数据在最后一个 chunk 返回，因此必须等流读完）
            await self._report_usage(
                model=model, usage=usage,
                latency_ms=int((time.time() - start) * 1000),
                trace_id=trace_id, scene=scene, is_stream=True,
            )
        except (APIError, APITimeoutError, RateLimitError) as e:
            log_event(logger, _WARNING, "llm_stream_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e)[:300])
            event_type = "timeout" if isinstance(e, APITimeoutError) else "model_error"
            await self._handle_model_failure(event_type, model, trace_id)
            if settings.enable_llm_fallback:
                async for piece in self._fallback_stream(messages, trace_id):
                    yield piece
            else:
                raise LlmFallbackError(friendly_timeout if isinstance(e, APITimeoutError) else str(e)) from e

    # ------------------- Token 用量上报（V39） -------------------

    async def _create_stream(
        self,
        model: str | None,
        messages: list[dict[str, str]],
        temperature: float | None,
        max_tokens: int | None,
    ) -> Any:
        """创建流式响应，并尽量请求携带 usage。

        OpenAI 兼容协议里 usage 需要 stream_options={"include_usage": True}，
        但各家兼容服务（星火/通义/vLLM 等）支持程度不一，因此逐级降级，
        保证拿不到 usage 时流式对话本身依然可用。
        """
        kwargs: dict[str, Any] = {
            "model": model or settings.llm_model,
            "messages": messages,
            "temperature": temperature if temperature is not None else settings.llm_temperature,
            "max_tokens": max_tokens or settings.llm_max_tokens,
            "stream": True,
        }
        try:
            return await self._client.chat.completions.create(
                **kwargs, stream_options={"include_usage": True}
            )
        except Exception:  # noqa: BLE001
            # 服务端/SDK 不支持 stream_options 时退回普通流式创建
            return await self._client.chat.completions.create(**kwargs)

    async def _report_usage(
        self,
        *,
        model: str | None,
        usage: Any,
        latency_ms: int,
        trace_id: str,
        scene: str,
        is_stream: bool,
        success: bool = True,
    ) -> None:
        """把本次调用的 token 用量上报业务中台落库。

        失败静默：统计是旁路能力，任何异常都不得影响主调用链路。
        延迟 import 以避免与 backend_client 形成循环依赖。
        """
        try:
            prompt = int(getattr(usage, "prompt_tokens", 0) or 0)
            completion = int(getattr(usage, "completion_tokens", 0) or 0)
            total = int(getattr(usage, "total_tokens", 0) or 0)
            if total <= 0:
                total = prompt + completion
            if total <= 0:
                return  # 未拿到有效用量（如服务端不支持 usage），不上报避免脏数据

            from app.services.backend_client import backend_client

            await backend_client.report_token_usage(
                model=model or settings.llm_model,
                prompt_tokens=prompt,
                completion_tokens=completion,
                total_tokens=total,
                latency_ms=latency_ms,
                scene=scene,
                success=success,
                is_stream=is_stream,
                trace_id=trace_id,
            )
        except Exception as e:  # noqa: BLE001
            log_event(
                logger, _WARNING, "token_usage_report_error",
                trace_id=trace_id, error=type(e).__name__, msg=str(e)[:200],
            )

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
                      trace_id=trace_id, error=type(e).__name__, msg=str(e)[:300])
            event_type = "timeout" if isinstance(e, APITimeoutError) else "model_error"
            await self._handle_model_failure(event_type, model, trace_id)
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
        # 仅进入降级态时上报一次「降级」，避免同一故障刷屏
        if not self._degraded:
            self._degraded = True
            await self._report_model_event(
                "degradation", "fallback", friendly_degradation,
                trace_id=trace_id, capability="LLM",
                detail={"fallback": settings.enable_llm_fallback},
            )
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

    # ------------------- 模型事件上报（对管理端可读、无敏感信息） -------------------
    async def _handle_model_failure(
        self, event_type: str, model: str | None, trace_id: str
    ) -> None:
        """记录一次模型失败/超时，并标记该模型为未恢复态"""
        key = self._resolved_key(model)
        self._failed_models.add(key)
        msg = friendly_timeout if event_type == "timeout" else friendly_error
        await self._report_model_event(
            event_type, key, msg,
            trace_id=trace_id, capability="LLM",
            detail={"fallback": settings.enable_llm_fallback},
        )

    async def _maybe_report_recovery(self, model: str | None, trace_id: str) -> None:
        """模型调用成功后，若此前处于降级/失败态则补报一次「恢复」事件（每个健康态只报一次）"""
        key = self._resolved_key(model)
        reported = False
        if self._degraded:
            self._degraded = False
            await self._report_model_event(
                "recovered", key, friendly_recovered,
                trace_id=trace_id, capability="LLM", recovered=True,
            )
            reported = True
        if key in self._failed_models:
            self._failed_models.discard(key)
            await self._report_model_event(
                "recovered", key, friendly_recovered,
                trace_id=trace_id, capability="LLM", recovered=True,
            )
            reported = True
        return reported

    def _resolved_key(self, model: str | None) -> str:
        """模型标识键：优先显式指定，否则取当前生效模型；空则用 fallback"""
        key = (model or settings.llm_model or "").strip()
        return key or "fallback"

    async def _report_model_event(
        self,
        event_type: str,
        model_name: str,
        error_msg: str,
        *,
        trace_id: str = "-",
        capability: str = "",
        recovered: bool = False,
        detail: dict[str, Any] | None = None,
    ) -> None:
        """模型事件异步回调业务中台（失败静默，不阻塞主流程）。
        只上报业务可读文案与模型标识，绝不携带密钥 / Authorization / 完整请求体。
        """
        try:
            from app.services.backend_client import backend_client  # noqa: PLC0415  # 延迟导入避免循环依赖
            await backend_client.log_model_event(
                event_type=event_type,
                model_name=model_name,
                error_message=error_msg,
                trace_id=trace_id,
                capability=capability,
                recovered=recovered,
                detail=detail or {},
            )
        except Exception as e:  # noqa: BLE001
            logger.warning("model_event 上报失败: %s", e)


# 模块级单例
llm_client = LlmClient()
