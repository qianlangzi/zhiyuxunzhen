"""批阅任务 handler；正式结果仍需通过 Spring Boot 回调持久化。"""
from typing import Any

from app.agents.reviewer_agent import review
from app.services.backend_client import backend_client
from app.core.errors import BackendDependencyError
from app.workers.base_worker import TaskWorker
from app.workers.task_queue import TaskQueue


async def handle_review(payload: dict[str, Any]) -> str | None:
    result = await review(payload["medicalRecordText"], payload.get("caseContext"), payload.get("traceId", "-"))
    callback_ok = await backend_client.review_callback(
        instance_id=int(payload["instanceId"]),
        total_score=float(result["totalScore"]),
        mistakes=result.get("mistakes", []),
        review_comment=result.get("reviewComment", ""),
        trace_id=payload.get("traceId", "-"),
    )
    if not callback_ok:
        raise BackendDependencyError("批阅结果回调 Spring Boot 失败")
    return f"review:{payload['instanceId']}"


def create_review_worker(queue: TaskQueue) -> TaskWorker:
    return TaskWorker(queue, "review", handle_review)
