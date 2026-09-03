"""Agent 工具注册与执行（function calling）。

工具让 Agent 能在推理过程中主动调用外部能力，而不是只依赖 workflow
预先注入的上下文。当前内置工具：

- ``search_textbook``：在医学教材知识库（Milvus + RAG）检索相关原文。
- ``report_exam_result``（兜底）：SP 在规则识别失败时主动确认某项检查已做，
  并返回该检查在病例预设清单里的预置结果。仅作用于 presetExams 预置项，
  不在清单的检查一律"没做过"，绝不现场编造数值/影像。

工具遵循 OpenAI 兼容的 function calling 协议：每个工具声明 name /
description / parameters（JSON Schema）。模型返回 ``tool_calls`` 后，
由 ``llm_client.resolve_tools`` 执行并把结果回填进消息，再继续生成。
"""
from __future__ import annotations

import json
from abc import ABC, abstractmethod
from typing import Any, Callable

from app.core.config import settings
from app.services.exam_dispatch import (
    build_report,
    parse_exam_menu,
    summary_for_sp,
)
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
            # rewrite=True：Agent 传来的口语化关键词先做医学术语规范化再检索
            citations = await rag_service.search(
                query, top_k=settings.rag_top_k, trace_id=trace_id, rewrite=True,
            )
        except Exception:  # noqa: BLE001 - 知识库不可用时返回可读提示
            return "知识库暂不可用，无法检索。"
        if not citations:
            return "未检索到相关教材内容。"
        return json.dumps(
            [c.model_dump() for c in citations], ensure_ascii=False
        )


class ReportExamResultTool(AgentTool):
    """（兜底）SP 确认某项检查已做并返回预置结果。

    仅作用于病例 presetExams 里预置的检查项。学生表达未被规则匹配时，SP
    可调用本工具主动安排"做完了"，工具把预置 result 通过 summary_for_sp
    转口语返回供 SP 转述，并通过 on_report 回调同步把结构化报告卡交
    consultation_graph 下发 `report` 事件。

    不在清单 / 无预置 result 的 → 返回"没做过"，不编造任何数据。
    """

    name = "report_exam_result"
    description = (
        "在病例的预设检查清单(presetExams)中确认某项检查已经完成并取出预置结果。"
        "适用场景：学生在对话中提到了某项检查但你（SP）需要从病例预置菜单里"
        "确认结果并自然转述。exam_name 必须是病例 presetExams 里的检查全称或"
        "常用别名（例如：心电图、肌钙蛋白、胸部CT）；若你不知道是否做过，直接"
        "回复患者说该项没做过即可，不要调用本工具。"
    )
    parameters = {
        "type": "object",
        "properties": {
            "exam_name": {
                "type": "string",
                "description": "病例 presetExams 中的检查全称或别名，例如：心电图、肌钙蛋白、胸部CT血管影像",
            }
        },
        "required": ["exam_name"],
    }

    def __init__(
        self,
        menu: list[dict[str, Any]] | None = None,
        on_report: Callable[[dict[str, Any]], None] | None = None,
    ) -> None:
        super().__init__()
        self._menu = menu or []
        self._on_report = on_report

    async def run(self, arguments: dict[str, Any], trace_id: str) -> str:
        exam_name = str(arguments.get("exam_name", "")).strip()
        if not exam_name:
            return "检查名为空。请用一句病人口吻回复医生：这项检查还没做。"
        target = _resolve_exam_item(exam_name, self._menu)
        if target is None:
            return "本病例的检查清单里没有这项检查。请用病人口吻回复医生：这项没做过。"
        if not target.get("result"):
            return "该项检查虽然在病例清单里但没有预置结果。请用病人口吻回复医生：报告还没出来。"
        report = build_report(target)
        if self._on_report is not None:
            try:
                self._on_report(report)
            except Exception:  # noqa: BLE001 - 报告收集失败不影响工具返回
                pass
        return summary_for_sp(target)


def _resolve_exam_item(name: str, menu: list[dict[str, Any]]) -> dict[str, Any] | None:
    """按全称/别名匹配菜单项；不依赖 LLM。"""
    import re
    needle = re.sub(r"\s+", "", name).lower()
    if not needle:
        return None
    for item in menu:
        item_name = re.sub(r"\s+", "", str(item.get("name", ""))).lower()
        if item_name and (item_name == needle or needle in item_name or item_name in needle):
            return item
        for alias in item.get("aliases") or []:
            alias_norm = re.sub(r"\s+", "", str(alias)).lower()
            if alias_norm and (alias_norm == needle or needle in alias_norm or alias_norm in needle):
                return item
    return None


# 全局工具注册表：name -> AgentTool（默认仅含 search_textbook；带病例菜单的
# report_exam_result 由 toolkit_list 按需实例化，避免污染全局）。
TOOLKIT: dict[str, AgentTool] = {
    tool.name: tool for tool in (SearchTextbookTool(),)
}


def toolkit_list(
    preset_exams_raw: Any | None = None,
    on_report: Callable[[dict[str, Any]], None] | None = None,
) -> list[AgentTool]:
    """返回当前工作流可用的全部工具。

    - preset_exams_raw 提供时，注册 report_exam_result 兜底工具（让 SP 在规则
      未识别时仍能主动确认）；菜单为空则不挂该工具，避免无意义调用。
    - on_report 为 SP 工具命中时把结构化报告卡收集到外层容器（统一由
      consultation_graph 负责 SSE `report` 事件下发）。
    """
    tools: list[AgentTool] = list(TOOLKIT.values())
    menu = parse_exam_menu(preset_exams_raw)
    if menu:
        tools.append(ReportExamResultTool(menu=menu, on_report=on_report))
    return tools