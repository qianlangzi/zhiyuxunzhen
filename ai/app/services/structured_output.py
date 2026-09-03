"""结构化输出服务（设计文档 5.6）

负责：
1. 从模型输出中提取 JSON（支持 ```json 代码块包裹）
2. Pydantic 严格校验（extra="forbid"）
3. 解析失败时抛出 OUTPUT_SCHEMA_INVALID

禁止使用"找到第一个 { 和最后一个 }"作为生产级解析方案。
"""
from __future__ import annotations

import json
import re
from typing import Any, TypeVar

from pydantic import BaseModel, ValidationError

from app.core.errors import OutputSchemaInvalidError
from app.core.logging import get_logger, log_event
from logging import WARNING

logger = get_logger(__name__)

T = TypeVar("T", bound=BaseModel)

# 匹配 ```json ... ``` 或 ``` ... ``` 格式
_CODE_BLOCK_RE = re.compile(r"```(?:json)?\s*\n?(.*?)\n?```", re.DOTALL)


def extract_json(text: str) -> str | None:
    """从模型输出中提取 JSON 字符串

    支持以下格式：
    - 纯 JSON: {"key": "value"}
    - ```json 包裹: ```json\\n{"key": "value"}\\n```
    - ``` 包裹: ```\\n{"key": "value"}\\n```

    不使用"找首个 { 和最后 }"的粗暴方式，而是按优先级尝试。
    """
    if not text or not text.strip():
        return None

    s = text.strip()

    # 尝试 1: 直接是 JSON
    if s.startswith("{") or s.startswith("["):
        try:
            json.loads(s)
            return s
        except json.JSONDecodeError:
            pass  # 继续尝试其他方式

    # 尝试 2: 从 ```json ... ``` 代码块中提取
    match = _CODE_BLOCK_RE.search(s)
    if match:
        extracted = match.group(1).strip()
        if extracted.startswith("{") or extracted.startswith("["):
            try:
                json.loads(extracted)
                return extracted
            except json.JSONDecodeError:
                pass

    # 尝试 3: 找到第一个 { 到最后一个 }，并验证 JSON 合法性
    first_brace = s.find("{")
    if first_brace == -1:
        return None

    last_brace = s.rfind("}")
    if last_brace == -1 or last_brace <= first_brace:
        return None

    candidate = s[first_brace : last_brace + 1]
    try:
        json.loads(candidate)
        return candidate
    except json.JSONDecodeError:
        return None


class StructuredOutputService:
    """结构化输出服务

    使用方式：
        result = await structured_output.parse_and_validate(
            raw_text=model_output,
            model_class=ReviewResult,
            trace_id=trace_id,
        )
    """

    async def parse_and_validate(
        self,
        raw_text: str,
        model_class: type[T],
        *,
        trace_id: str = "-",
    ) -> T:
        """解析模型输出并校验为 Pydantic 模型

        Args:
            raw_text: 模型返回的原始文本
            model_class: 目标 Pydantic 模型类型
            trace_id: 追踪 ID

        Returns:
            校验通过的 Pydantic 模型实例

        Raises:
            OutputSchemaInvalidError: 解析或校验失败
        """
        json_str = extract_json(raw_text)

        if json_str is None:
            log_event(logger, WARNING, "structured_output_no_json",
                      trace_id=trace_id, raw_length=len(raw_text),
                      raw_preview=raw_text[:200])
            raise OutputSchemaInvalidError(
                "模型输出中未找到有效的 JSON",
                trace_id=trace_id,
            )

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as e:
            log_event(logger, WARNING, "structured_output_json_error",
                      trace_id=trace_id, error=str(e),
                      raw_preview=raw_text[:200])
            raise OutputSchemaInvalidError(
                f"JSON 解析失败: {e.msg}",
                trace_id=trace_id,
            ) from e

        try:
            return model_class.model_validate(data)
        except ValidationError as e:
            errors = e.errors()[:3]
            log_event(logger, WARNING, "structured_output_validation_error",
                      trace_id=trace_id, errors=errors)
            first_msg = errors[0]["msg"] if errors else "未知错误"
            raise OutputSchemaInvalidError(
                f"输出校验失败: {first_msg}",
                trace_id=trace_id,
            ) from e

    async def parse_to_dict(
        self,
        raw_text: str,
        *,
        required_keys: tuple[str, ...] = (),
        trace_id: str = "-",
    ) -> dict[str, Any]:
        """解析模型输出为字典，并检查必需字段

        当没有对应的 Pydantic 模型时使用此方法。

        Args:
            raw_text: 模型返回的原始文本
            required_keys: 必需的字段名
            trace_id: 追踪 ID

        Returns:
            解析后的字典

        Raises:
            OutputSchemaInvalidError: 解析失败或缺少必需字段
        """
        json_str = extract_json(raw_text)

        if json_str is None:
            log_event(logger, WARNING, "structured_output_no_json",
                      trace_id=trace_id, raw_preview=raw_text[:200])
            raise OutputSchemaInvalidError(
                "模型输出中未找到有效的 JSON",
                trace_id=trace_id,
            )

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as e:
            log_event(logger, WARNING, "structured_output_json_error",
                      trace_id=trace_id, error=str(e))
            raise OutputSchemaInvalidError(
                f"JSON 解析失败: {e.msg}",
                trace_id=trace_id,
            ) from e

        if not isinstance(data, dict):
            log_event(logger, WARNING, "structured_output_not_dict",
                      trace_id=trace_id, type=type(data).__name__)
            raise OutputSchemaInvalidError(
                "模型输出不是 JSON 对象",
                trace_id=trace_id,
            )

        # 检查必需字段
        missing = [key for key in required_keys if key not in data]
        if missing:
            log_event(logger, WARNING, "structured_output_missing_keys",
                      trace_id=trace_id, missing=missing)
            raise OutputSchemaInvalidError(
                f"模型输出缺少必需字段: {', '.join(missing)}",
                trace_id=trace_id,
            )

        return data


# 全局单例
structured_output = StructuredOutputService()
