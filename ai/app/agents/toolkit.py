"""Agent 工具注册与执行（function calling）。

工具让 Agent 能在推理过程中主动调用外部能力，而不是只依赖 workflow
预先注入的上下文。当前内置一个工具：

- ``search_textbook``：在医学教材知识库（Milvus + RAG）检索相关原文。

工具遵循 OpenAI 兼容的 function calling 协议：每个工具声明 name /
description / parameters（JSON Schema）。模型返回 ``tool_calls`` 后，
由 ``llm_client.resolve_tools`` 执行并把结果回填进消息，再继续生成。
"""
from __future__ import annotations

import json
from abc import ABC, abstractmethod
from typing import Any

from app.services.rag_service import rag_service


class AgentTool(ABC):
    """工具基类。"""

    name: str = ""
    description: str = ""
    parameters: dict[str, Any] = {}

    def schema(self) -> dict[str, Any]:
        """OpenAI 兼容的 tool 声明。"""
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters,
            },
        }

    @abstractmethod
    async def run(self, arguments: dict[str, Any], trace_id: str) -> str:
        """执行工具，返回可被模型消费的字符串结果。"""


class SearchTextbookTool(AgentTool):
    """检索医学教材知识库，返回相关原文与出处。"""

    name = "search_textbook"
    description = (
        "在医学教材知识库中检索与症状、疾病、检查、诊断相关的原文段落，"
        "返回相关出处（书名/章节/页码/原文片段）。当需要确认某个医学知识点时可调用。"
    )
    parameters = {
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "要检索的医学关键词，例如：胸痛鉴别诊断"}
        },
        "required": ["query"],
    }

    async def run(self, arguments: dict[str, Any], trace_id: str) -> str:
        query = str(arguments.get("query", "")).strip()
        if not query:
            return "检索关键词不能为空。"
        try:
            citations = await rag_service.search(query, top_k=3, trace_id=trace_id)
        except Exception:  # noqa: BLE001 - 知识库不可用时返回可读提示
            return "知识库暂不可用，无法检索。"
        if not citations:
            return "未检索到相关教材内容。"
        return json.dumps(
            [c.model_dump() for c in citations], ensure_ascii=False
        )


# 全局工具注册表：name -> AgentTool
TOOLKIT: dict[str, AgentTool] = {
    tool.name: tool for tool in (SearchTextbookTool(),)
}


def toolkit_list() -> list[AgentTool]:
    """返回全部工具列表，便于传入 resolve_tools。"""
    return list(TOOLKIT.values())