"""SP Agent：扮演虚拟病人（PRD 7.2）

输入：学生最新消息 + 病例上下文 + 历史对话 + 当前问诊阶段
输出：SP 流式回复

工具感知：``sp_reply_stream_with_tools`` 在流式生成前先执行一轮工具调用
（如检索教材知识库），把工具结果回填进上下文，让 SP 能"主动查教材"。
"""
from collections.abc import AsyncIterator

from app.adapters.model_gateway import model_gateway
from app.core.logging import get_logger
from app.prompts.templates import sp_agent_prompt

logger = get_logger(__name__)


def build_sp_messages(
    case_context: str,
    history: list[dict[str, str]],
    stage: str = "主诉采集",
) -> list[dict[str, str]]:
    """组装 LLM messages：system + 历史 + 当前 student 消息"""
    messages: list[dict[str, str]] = [{"role": "system", "content": sp_agent_prompt(case_context, stage)}]
    messages.extend(history)
    return messages


async def sp_reply_stream(
    case_context: str,
    history: list[dict[str, str]],
    trace_id: str = "-",
    stage: str = "主诉采集",
) -> AsyncIterator[str]:
    """流式返回 SP 回复"""
    messages = build_sp_messages(case_context, history, stage=stage)
    async for delta in model_gateway.stream(messages, trace_id=trace_id):
        yield delta


async def sp_reply_stream_with_tools(
    case_context: str,
    history: list[dict[str, str]],
    tools: list,
    *,
    trace_id: str = "-",
    stage: str = "主诉采集",
) -> AsyncIterator[str]:
    """带工具调用的 SP 流式回复。

    先执行一轮工具调用（模型可决定是否检索教材），把工具结果回填进
    messages，再流式生成最终回复。降级/未配置 LLM 时退化为无工具路径。
    """
    messages = build_sp_messages(case_context, history, stage=stage)
    messages = await model_gateway.resolve_tools(messages, tools, trace_id=trace_id)
    async for delta in model_gateway.stream(messages, trace_id=trace_id):
        yield delta
