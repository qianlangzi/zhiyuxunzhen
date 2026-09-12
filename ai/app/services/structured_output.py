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
    if last_brace != -1 and last_brace > first_brace:
        candidate = s[first_brace : last_brace + 1]
        try:
            json.loads(candidate)
            return candidate
        except json.JSONDecodeError:
            pass

    # 尝试 4（截断兜底）: 模型输出被 max_tokens 截断时 JSON 不完整
    # （finish_reason=length，可能连一个 } 都没有），围栏未闭合、
    # 尾部缺括号。做括号/引号平衡修复后再次校验，
    # 救回「内容完整、仅尾部被截」的输出。
    repaired = _repair_truncated_json(s[first_brace:])
    if repaired is not None:
        return repaired

    return None


# 对象/数组闭合符前残留的逗号（模型与截断修复的高频产物）
_TRAILING_COMMA_RE = re.compile(r",\s*(?=[}\]])")

# 尾部回退尝试的最大切割点数量（避免超长输出下的无谓扫描）
_MAX_CUT_POINTS = 40


def _strip_trailing_commas(text: str) -> str:
    """删除闭合符前的多余逗号：{"a":1,} → {"a":1}"""
    return _TRAILING_COMMA_RE.sub("", text)


def _scan_structure(prefix: str) -> tuple[list[str], bool] | None:
    """扫描前缀的括号/字符串状态

    Returns:
        (未闭合的括号栈, 是否停在字符串中间)；结构已错（多余的 } / ]）返回 None
    """
    stack: list[str] = []
    in_string = False
    escape = False
    for ch in prefix:
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch in "{[":
            stack.append(ch)
        elif ch in "}]":
            if not stack:
                return None
            stack.pop()
    return stack, in_string


def _close_prefix(prefix: str) -> str | None:
    """把 JSON 前缀补成完整文档：字符串截断补引号 → 按栈逆序补闭合符 → 去尾随逗号"""
    scanned = _scan_structure(prefix)
    if scanned is None:
        return None
    stack, in_string = scanned
    closed = prefix + ('"' if in_string else "")
    closed += "".join("}" if c == "{" else "]" for c in reversed(stack))
    return _strip_trailing_commas(closed)


def _safe_cut_points(fragment: str) -> list[int]:
    """收集"可安全截断"的位置：元素之间的逗号处（从后往前，最多 _MAX_CUT_POINTS 个）

    截断修复的价值在于：模型被 max_tokens 截断时，尾部常停在下个字段的名字或冒号上
    （如 `..."presetExams`、`..."key":`），直接补括号得到的是非法 JSON。退到上一个
    完整元素再闭合，就能救回"内容基本完整、仅尾部被截"的输出——缺失字段由其默认值
    兜底，比整条链路 422 失败对教师友好得多。
    """
    points: list[int] = []
    stack: list[str] = []
    in_string = False
    escape = False
    for idx, ch in enumerate(fragment):
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch in "{[":
            stack.append(ch)
        elif ch in "}]":
            if not stack:
                return points
            stack.pop()
        elif ch == "," and stack:
            points.append(idx)
    return points[-_MAX_CUT_POINTS:]


def _repair_truncated_json(fragment: str) -> str | None:
    """修复被截断的 JSON；无法修复时返回 None

    策略（按优先级）：① 原样补齐闭合符；② 逐级回退到最近的安全截断点再补齐。
    每条候选都必须真正通过 json.loads 才返回，绝不把"看起来像 JSON"的字符串
    交给下游——下游按非法 JSON 处理会报出误导性的"未找到有效的 JSON"。
    """
    candidates: list[str] = []
    direct = _close_prefix(fragment)
    if direct is not None:
        candidates.append(direct)
    for cut in reversed(_safe_cut_points(fragment)):
        candidate = _close_prefix(fragment[:cut])
        if candidate is not None:
            candidates.append(candidate)
    for candidate in candidates:
        try:
            json.loads(candidate)
            return candidate
        except json.JSONDecodeError:
            continue
    return None


def _no_json_message(raw_text: str) -> str:
    """区分"空输出"与"截断输出"，给出可诊断的提示

    旧文案统一为"模型输出中未找到有效的 JSON"，把"被 max_tokens 截断"误导成
    "模型没给 JSON"，排障时只能靠猜（2026-09-12 线上教师端即为此类误报）。
    """
    if not raw_text or not raw_text.strip():
        return "模型返回内容为空，请重试"
    return "模型输出不完整（疑似被长度上限截断），请重试"


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
                _no_json_message(raw_text),
                trace_id=trace_id,
                details={"retryable": True, "reason": "no_json",
                         "raw_length": len(raw_text.strip())},
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
                details={"retryable": True, "reason": "json_decode"},
            ) from e

        try:
            return model_class.model_validate(data)
        except ValidationError as e:
            errors = e.errors()[:3]
            log_event(logger, WARNING, "structured_output_validation_error",
                      trace_id=trace_id, errors=errors)
            # 首条错误的字段路径放进文案：教师端 toast 直接展示 message，
            # 只给"不符合要求"无从下手，带上字段名至少能定位（原始英文错误进 details）
            loc = ".".join(str(p) for p in errors[0].get("loc", ())) if errors else ""
            raise OutputSchemaInvalidError(
                f"AI 输出字段不符合要求{'（' + loc + '）' if loc else ''}，请重试",
                trace_id=trace_id,
                details={"retryable": False, "reason": "validation", "errors": errors},
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
                _no_json_message(raw_text),
                trace_id=trace_id,
                details={"retryable": True, "reason": "no_json",
                         "raw_length": len(raw_text.strip())},
            )

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as e:
            log_event(logger, WARNING, "structured_output_json_error",
                      trace_id=trace_id, error=str(e))
            raise OutputSchemaInvalidError(
                f"JSON 解析失败: {e.msg}",
                trace_id=trace_id,
                details={"retryable": True, "reason": "json_decode"},
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
