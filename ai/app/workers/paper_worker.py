"""AI 组卷异步 Worker（复用 task_queue 的 TaskQueue + TaskWorker 机制）。
Java 业务中台负责候选组装+规则兜底+题目解析；AI 中台负责异步调度+LLM 选题组卷。
"""
import uuid
from app.core.logging import ensure_trace_id
from typing import Any

from app.domain.enums import TaskStatus, TaskType
from app.workers.base_worker import TaskWorker
from app.workers.task_queue import TaskQueue
from app.services.llm_client import llm_client


def _to_user_msg(payload: dict[str, Any]) -> str:
    lines = [
        f"学生 ID：{payload.get('studentId')}",
        f"目标题量：{payload.get('count')}",
        f"难度偏好：{payload.get('difficulty') or '不限'}",
        f"薄弱知识点：{'、'.join(payload.get('focusTags') or []) or '（暂无统计）'}",
        "候选题目列表：",
    ]
    for c in payload.get('candidates') or []:
        diff = {1: "简单", 2: "标准", 3: "困难"}.get(c.get('difficulty'), "未知")
        lines.append(f"- id={c.get('id')} | {c.get('knowledgeTag') or '未知'} | {diff} | "
                     f"{c.get('questionType') or 'unknown'} | {c.get('title') or '（无题干）'}")
    lines.append("请仅从候选中选题组卷，禁止编造题目。")
    return "\n".join(lines)


def _degraded() -> dict[str, Any]:
    return {"paperTitle": "", "selectedIds": [], "source": "RULE", "status": "DEGRADED"}


async def paper_handler(payload: dict[str, Any]) -> dict[str, Any]:
    trace_id = ensure_trace_id()
    messages = [
        {"role": "system", "content": "请作为医学组卷助手，从给定候选中挑选最贴合学生薄弱点的题目。"},
        {"role": "user", "content": _to_user_msg(payload)},
    ]
    try:
        result = await llm_client.chat_json(messages, trace_id=trace_id)
    except Exception:
        return _degraded()

    raw_ids = result.get("selectedIds") if isinstance(result, dict) else None
    if not isinstance(raw_ids, list) or not raw_ids:
        return _degraded()

    allowed = {c.get("id") for c in payload.get("candidates") or []}
    valid = []
    for i in raw_ids:
        try:
            iid = int(i)
        except (TypeError, ValueError):
            continue
        if iid in allowed and iid not in valid:
            valid.append(iid)

    return {
        "paperTitle": str(result.get("paperTitle") or "").strip() or "个性化自测卷",
        "selectedIds": valid,
        "rationale": str(result.get("rationale") or "").strip(),
        "source": "AI",
        "status": "SUCCESS",
    }


def create_paper_worker(queue: TaskQueue) -> TaskWorker:
    return TaskWorker(queue=queue, task_type=TaskType.PAPER.value, handler=paper_handler)