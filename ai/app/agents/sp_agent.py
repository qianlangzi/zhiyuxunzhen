"""SP Agent：扮演虚拟病人（PRD 7.2）

输入：学生最新消息 + 病例上下文 + 历史对话 + 当前问诊阶段
输出：SP 流式回复

工具感知：``sp_reply_stream_with_tools`` 在流式生成前先执行一轮工具调用
（如检索教材知识库），把工具结果回填进上下文，让 SP 能"主动查教材"。

主动开场：``build_sp_messages`` 在 history 为空（即学生还未发问）时追加一条隐性
系统引导，让 SP 用 1~2 句病人口吻自然开场。开场规则不污染持久化历史，
仅在 LLM 输入侧生效，因此不会写回 ChatSession 消息表。
"""
from collections.abc import AsyncIterator

from app.adapters.model_gateway import model_gateway
from app.core.config import settings
from app.core.logging import get_logger
from app.prompts.templates import sp_agent_prompt
from app.services.config_center import config_center

logger = get_logger(__name__)


def _sampling() -> tuple[float, int]:
    """读取 Agent「sp」的采样参数覆盖（AI 配置中心 · Agent 元参数层热改）"""
    return config_center.agent_sampling(
        "sp", settings.llm_temperature, settings.llm_max_tokens
    )


# 主动开场引导：仅在 history 为空时追加到 system 段尾部。
# 说明性：保留 SP 系统提示词正文完整，本引导作为「运行时规则注入」，避免管理端
# 改写内置 SP prompt 时把这条覆盖掉；同时不写回对话历史，干净可控。
_OPENING_GUIDE = (
    "\n\n[运行时规则 · 主动开场] 当前历史为空（学生尚未发问），"
    "请在本次回复中用 1~2 句**病人口吻**主动开场，自然引入病例的主诉症状；"
    "必须保持患者身份，不直接透露诊断、不使用医学术语，并鼓励医学生开始问诊。"
    "如病例上下文包含主诉字段，参考其要点组织语言；若主诉不明确则用『不太舒服来看看』式开场。"
)


def build_sp_messages(
    case_context: str,
    history: list[dict[str, str]],
    stage: str = "主诉采集",
) -> list[dict[str, str]]:
    """组装 LLM messages：system（按需追加主动开场引导） + 历史 + 当前 student 消息"""
    system_text = sp_agent_prompt(case_context, stage)
    if not history:
        # 空历史 → 追加隐性引导，提醒 SP 主动开口
        system_text = system_text + _OPENING_GUIDE
    messages: list[dict[str, str]] = [{"role": "system", "content": system_text}]
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
    temperature, max_tokens = _sampling()
    async for delta in model_gateway.stream(
        messages, temperature=temperature, max_tokens=max_tokens, trace_id=trace_id
    ):
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
    messages = await model_gateway.resolve_tools(
        messages, tools, agent_code="sp", trace_id=trace_id
    )
    temperature, max_tokens = _sampling()
    async for delta in model_gateway.stream(
        messages, temperature=temperature, max_tokens=max_tokens, trace_id=trace_id
    ):
        yield delta
