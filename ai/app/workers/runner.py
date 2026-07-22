"""Worker process entrypoint: ``python -m app.workers.runner``."""
import asyncio
import logging
import os

from app.core import lifecycle
from app.workers.knowledge_worker import create_knowledge_worker
from app.workers.report_worker import create_report_worker
from app.workers.review_worker import create_review_worker
from app.workers.task_queue import TaskQueue

logger = logging.getLogger(__name__)


async def run() -> None:
    await lifecycle.startup()
    try:
        if lifecycle.resources.redis_client is None:
            raise RuntimeError("Worker requires Redis")
        queue = TaskQueue(lifecycle.resources.redis_client)
        enabled = {
            item.strip() for item in os.getenv("AI_WORKER_TYPES", "review,report,knowledge_ingest").split(",") if item.strip()
        }
        workers = [
            worker
            for name, worker in (
                ("review", create_review_worker(queue)),
                ("report", create_report_worker(queue)),
                ("knowledge_ingest", create_knowledge_worker(queue)),
            )
            if name in enabled
        ]
        if not workers:
            raise RuntimeError("AI_WORKER_TYPES did not enable any known worker")
        poll_seconds = max(0.1, float(os.getenv("AI_WORKER_POLL_SECONDS", "1")))
        logger.info("AI worker started: %s", sorted(enabled))
        while True:
            processed = False
            for worker in workers:
                processed = await worker.run_once() is not None or processed
            if not processed:
                await asyncio.sleep(poll_seconds)
    finally:
        await lifecycle.shutdown()


if __name__ == "__main__":
    asyncio.run(run())
