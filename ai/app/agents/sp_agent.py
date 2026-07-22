"""SP Agent：扮演虚拟病人（PRD 7.2）

输入：学生最新消息 + 病例上下文 + 历史对话
输出：SP 流式回复
"""
from collections.abc import AsyncIterator

from app.core.logging import get_logger
from app.prompts.templates import sp_agent_prompt
from app.adapters.model_gateway import model_gateway

logger = get_logger(__name__)


def build_sp_messages(
    case_context: str,
    history: list[dict[str, str]],
) -> list[dict[str, str]]:
    """组装 LLM messages：system + 历史 + 当前 student 消息"""
    messages: list[dict[str, str]] = [{"role": "system", "content": sp_agent_prompt(case_context)}]
    messages.extend(history)
    return messages


async def sp_reply_stream(
    case_context: str,
    history: list[dict[str, str]],
    trace_id: str = "-",
) -> AsyncIterator[str]:
    """流式返回 SP 回复"""
    messages = build_sp_messages(case_context, history)
    async for delta in model_gateway.stream(messages, trace_id=trace_id):
        yield delta
