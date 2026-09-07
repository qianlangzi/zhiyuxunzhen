"""检查请求 → 病例预置报告卡（L0/L1 确定性下发）

设计目标（2026-09-03 与老大拍板）：
- 运行期绝不现场生图或编造数值；报告卡内容只来自病例 preset_exams 教师预置的
  result（金标准），由本模块解析 → 下发给移动端做确定性渲染。
- 触发 = 规则匹配为主：学生本轮消息与病例检查菜单（presetExams）做精确名/别名
  匹配，命中且有 result 才下发；未命中 = 该项检查等于没做，零幻觉。
- 不依赖 LLM 工具调用决定"给不给报告"，但配合 toolkit.RequestExamTool
  （SP 在规则未识别时仍可主动确认）形成兜底链路。

质量锁：报告卡内容字段一律从病例数据而来，不引入 LLM 自由发挥。
"""
from __future__ import annotations

import json
import re
from typing import Any


def parse_exam_menu(raw: Any) -> list[dict[str, Any]]:
    """把后端透传的 presetExams 字符串解析成菜单列表。

    兼容性：None / 非字符串 / 空串 / 坏 JSON / 非列表 → 返回 []。
    单条非 dict 项 → 跳过。
    """
    if not raw or not isinstance(raw, str):
        return []
    text = raw.strip()
    if not text:
        return []
    try:
        data = json.loads(text)
    except Exception:  # noqa: BLE001 - 病例配置脏数据不应阻断问诊
        return []
    if not isinstance(data, list):
        return []
    items: list[dict[str, Any]] = []
    for it in data:
        if isinstance(it, dict) and it.get("name"):
            items.append(it)
    return items


def _normalize(text: str) -> str:
    """匹配用归一：去空白、转小写。"""
    return re.sub(r"\s+", "", (text or "")).lower()


def match_exams(user_text: str, menu: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """在病例菜单里匹配学生本轮消息提到的检查。

    匹配规则（确定性，不靠 LLM）：
    1. 检查名（item.name）与学生文本子串匹配（去空白、不区分大小写），
       且长度 ≥ 2 字，避免"做""个""查"等单字误伤。
    2. item.aliases 列表里的任一别名在文本中出现，也算命中。
    3. 同时支持英文/缩写（大小写不敏感）。

    命中顺序按菜单原顺序，方便前端按学生语义顺序渲染。
    返回命中项（含 result），未命中返回 []。
    """
    norm_user = _normalize(user_text)
    if not norm_user:
        return []
    hits: list[dict[str, Any]] = []
    for item in menu:
        name = _normalize(str(item.get("name", "")))
        if len(name) >= 2 and name in norm_user:
            hits.append(item)
            continue
        aliases = item.get("aliases") or []
        if any(_normalize(str(a)) in norm_user for a in aliases):
            hits.append(item)
    return hits


def build_report(item: dict[str, Any]) -> dict[str, Any]:
    """把检查项（含 result）转成 SSE `report` 事件 payload。

    字段尽量扁平且与 result 子结构一致；前端按 kind 决定如何渲染。
    result 缺失或 kind 缺失 → 返回空 result 的最小骨架，移动端可降级显示。
    """
    result = item.get("result") or {}
    payload: dict[str, Any] = {
        "examName": item.get("name"),
        "cost": item.get("cost"),
        "mark": item.get("mark"),
        "kind": result.get("kind") or "text",
        "conclusion": result.get("conclusion") or "",
    }
    kind = result.get("kind")
    if kind == "ecg" and isinstance(result.get("ecg"), dict):
        payload["ecg"] = result["ecg"]
    if kind == "lab" and isinstance(result.get("table"), list):
        payload["table"] = result["table"]
    # imageKeys 跨 kind 透传：image 报告单自然要附图；ecg 报告单也可附患者心电图照片
    keys = result.get("imageKeys") or []
    if isinstance(keys, list):
        valid_keys = [k for k in keys if isinstance(k, str) and k]
        if valid_keys:
            payload["imageKeys"] = valid_keys
    # imageUrls 透传：教师上传的自备素材（Java uploads 静态 URL，无需 AI 中台索引）
    urls = result.get("imageUrls") or []
    if isinstance(urls, list):
        valid_urls = [u for u in urls if isinstance(u, str) and u]
        if valid_urls:
            payload["imageUrls"] = valid_urls
    return payload


def _format_lab_row(row: dict[str, Any]) -> str:
    parts: list[str] = []
    item = row.get("item")
    if item:
        parts.append(str(item))
    value = row.get("value")
    unit = row.get("unit")
    if value is not None:
        seg = f"{value}{(' ' + unit) if unit else ''}"
        if row.get("flag"):
            seg += f"（{row['flag']}）"
        parts.append(seg)
    return "：".join(parts) if parts else ""


def summary_for_sp(item: dict[str, Any]) -> str:
    """给 SP 转述的口语化结果锚点（注入 case_context 让 LLM 用病人口吻说出来）。

    原则：要点 + 异常项，不复述全部数值（图形报告卡已经把数值展示给医生）。
    """
    name = item.get("name", "该项检查")
    result = item.get("result") or {}
    kind = result.get("kind")
    conclusion = result.get("conclusion") or ""

    if kind == "lab" and isinstance(result.get("table"), list):
        rows = [r for r in result["table"] if isinstance(r, dict) and r.get("flag")]
        if rows:
            abnormal = "、".join(_format_lab_row(r) for r in rows[:3])
            return (
                f"{name}已做（关键异常：{abnormal}）；"
                "报告单已经给医生看了，你按病人口吻简单说一句就行。"
            )
        return f"{name}已做，数值都在正常范围；报告单已经给医生看了。"
    if kind == "ecg":
        return (
            f"{name}已做（{conclusion or '详见报告单'}）；"
            "报告单已经给医生看了。"
        )
    if kind == "image":
        return (
            f"{name}已做（{conclusion or '所见详见报告单'}）；"
            "报告单已经给医生看了。"
        )
    return f"{name}已做，结果：{conclusion or '详见报告单'}；报告单已经给医生看了。"