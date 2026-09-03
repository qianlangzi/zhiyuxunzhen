"""Worker process entrypoint: ``python -m app.workers.runner``."""
import asyncio
import logging
import os

from app.core import lifecycle
from app.core.logging import configure_logging
from app.workers.base_worker import TaskWorker
from app.workers.knowledge_worker import create_knowledge_worker
from app.workers.paper_worker import create_paper_worker
from app.workers.review_worker import create_review_worker
from app.workers.task_queue import TaskQueue

logger = logging.getLogger(__name__)


async def _consume_loop(worker: TaskWorker, poll_seconds: float) -> None:
    """单个消费者循环：持续 claim 任务并执行。

    并发多个该循环即为多消费者并行，任务由 Redis 队列原子分发，
    每个消费者拿到不同任务，天然支持教材并行入库。
    """
    while True:
        processed = await worker.run_once() is not None
        if not processed:
            await asyncio.sleep(poll_seconds)


async def run() -> None:
    configure_logging()
    await lifecycle.startup()
    try:
        if lifecycle.resources.redis_client is None:
            raise RuntimeError("Worker requires Redis")
        queue = TaskQueue(lifecycle.resources.redis_client)
        enabled = {
            item.strip() for item in os.getenv("AI_WORKER_TYPES", "review,knowledge_ingest,paper").split(",") if item.strip()
        }
        workers = [
            worker
            for name, worker in (
                ("review", create_review_worker(queue)),
                ("knowledge_ingest", create_knowledge_worker(queue)),
                ("paper", create_paper_worker(queue)),
            )
            if name in enabled
        ]
        if not workers:
            raise RuntimeError("AI_WORKER_TYPES did not enable any known worker")
        poll_seconds = max(0.1, float(os.getenv("AI_WORKER_POLL_SECONDS", "1")))
        # 每个 worker 类型的并发消费者数（教材入库加速：多本教材并行向量化）。
        # 注意：每本教材内部 embedding 已有 embed_concurrency=8 并发，
        # 并发 N 本会使 embedding 总并发放大到 N*8，需结合 DashScope 配额权衡。
        concurrency = max(1, int(os.getenv("AI_WORKER_CONCURRENCY", "1")))
        logger.info("AI worker started: %s (concurrency=%d)", sorted(enabled), concurrency)
        loops = [
            asyncio.create_task(_consume_loop(worker, poll_seconds))
            for worker in workers
            for _ in range(concurrency)
        ]
        await asyncio.gather(*loops)
    finally:
        await lifecycle.shutdown()


if __name__ == "__main__":
    asyncio.run(run())
