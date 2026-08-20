"""Milvus 向量库封装（PRD 7.3）

特性：
1. 懒连接：首次使用时才尝试连接 Milvus，失败时根据 enable_milvus_fallback 切换内存索引
2. 内存索引使用余弦相似度，结果与 Milvus 近似但仅适合小规模数据
3. collection 自动创建，schema：id / vector / book_name / edition / chapter / page_number / chunk_text
4. 同步 pymilvus 调用通过 asyncio.to_thread 放入线程池，不阻塞 FastAPI 事件循环
"""
import asyncio
import math
import threading
from typing import Any

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.core.errors import RetrievalUnavailableError

logger = get_logger(__name__)

_COLLECTION_FIELDS = ["book_name", "edition", "chapter", "page_number", "chunk_text", "subject", "part", "section"]


class _MemoryIndex:
    """内存倒排索引，用于 Milvus 不可用时兜底"""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._records: list[dict[str, Any]] = []

    def upsert(self, records: list[dict[str, Any]]) -> int:
        with self._lock:
            self._records.extend(records)
        return len(records)

    def search(self, query_vec: list[float], top_k: int = 5) -> list[dict[str, Any]]:
        if not self._records:
            return []
        scored = []
        with self._lock:
            snapshot = list(self._records)
        for rec in snapshot:
            score = _cosine(query_vec, rec.get("vector", []))
            scored.append((score, rec))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [
            {**rec, "score": float(score)}
            for score, rec in scored[:top_k]
        ]

    def count(self) -> int:
        return len(self._records)


def _cosine(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b, strict=True))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


class MilvusService:
    """Milvus 客户端，带内存 fallback"""

    def __init__(self) -> None:
        self._client: Any | None = None
        self._connected = False
        self._use_memory = False
        self._memory = _MemoryIndex()

    def _connect_sync(self) -> bool:
        """同步连接 Milvus 并确保 collection 存在（在线程池中执行）"""
        from pymilvus import MilvusClient, DataType  # type: ignore[import-untyped]

        client = MilvusClient(uri=f"http://{settings.milvus_host}:{settings.milvus_port}")
        client.list_collections()
        self._client = client

        # 确保 collection 存在
        name = settings.milvus_collection
        if name not in client.list_collections():
            schema = client.create_schema(auto_id=False, enable_dynamic_field=False)
            schema.add_field("id", DataType.VARCHAR, is_primary=True, max_length=64)
            schema.add_field("vector", DataType.FLOAT_VECTOR, dim=settings.milvus_vector_dim)
            schema.add_field("book_name", DataType.VARCHAR, max_length=200)
            schema.add_field("edition", DataType.VARCHAR, max_length=50)
            schema.add_field("chapter", DataType.VARCHAR, max_length=200)
            schema.add_field("page_number", DataType.INT64)
            schema.add_field("chunk_text", DataType.VARCHAR, max_length=4000)
            schema.add_field("subject", DataType.VARCHAR, max_length=128)
            schema.add_field("part", DataType.VARCHAR, max_length=256)
            schema.add_field("section", DataType.VARCHAR, max_length=256)
            index_params = client.prepare_index_params()
            index_params.add_index(
                field_name="vector", index_type="AUTOINDEX", metric_type="COSINE"
            )
            index_params.add_index(
                field_name="subject", index_type="INVERTED"
            )
            index_params.add_index(
                field_name="chapter", index_type="INVERTED"
            )
            client.create_collection(
                collection_name=name, schema=schema, index_params=index_params
            )
            log_event(logger, INFO, "milvus_collection_created", name=name)

        return True

    async def _ensure_connected(self) -> bool:
        """首次使用时尝试连接 Milvus；失败则切到内存模式"""
        if self._connected:
            return self._client is not None and not self._use_memory
        if self._use_memory:
            return False
        try:
            # 同步 pymilvus 调用放入线程池，不阻塞事件循环
            await asyncio.to_thread(self._connect_sync)
            self._connected = True
            log_event(logger, INFO, "milvus_connected",
                      host=settings.milvus_host, port=settings.milvus_port)
            return True
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "milvus_unavailable",
                      error=type(e).__name__, msg=str(e),
                      fallback=settings.enable_milvus_fallback)
            self._use_memory = settings.enable_milvus_fallback
            self._connected = True
            return False

    async def upsert(
        self,
        records: list[dict[str, Any]],
        trace_id: str = "-",
    ) -> int:
        """插入或更新向量记录"""
        if not records:
            return 0
        use_milvus = await self._ensure_connected()
        if not use_milvus and not settings.enable_milvus_fallback:
            raise RetrievalUnavailableError("Milvus 服务不可用", trace_id)
        if use_milvus and self._client:
            try:
                # 同步 pymilvus 调用放入线程池
                await asyncio.to_thread(
                    self._client.upsert,
                    collection_name=settings.milvus_collection,
                    data=records,
                )
                log_event(logger, INFO, "milvus_upsert_ok",
                          trace_id=trace_id, count=len(records))
                return len(records)
            except Exception as e:  # noqa: BLE001
                log_event(logger, WARNING, "milvus_upsert_error",
                          trace_id=trace_id, error=type(e).__name__, msg=str(e))
                if not settings.enable_milvus_fallback:
                    raise RetrievalUnavailableError("Milvus 写入失败", trace_id) from e
                self._use_memory = True
        # 内存 fallback
        return self._memory.upsert(records)

    async def search(
        self,
        query_vec: list[float],
        top_k: int = 5,
        trace_id: str = "-",
        subject_filter: str | None = None,
        collection_name: str | None = None,
    ) -> list[dict[str, Any]]:
        """向量相似度检索，返回 top_k 条带 score 的记录。

        Args:
            subject_filter: 学科过滤（如 "内科"/"心电"），None 表示不过滤
            collection_name: 指定 collection，None 用默认 settings.milvus_collection
        """
        use_milvus = await self._ensure_connected()
        if not use_milvus and not settings.enable_milvus_fallback:
            raise RetrievalUnavailableError("Milvus 服务不可用", trace_id)
        if use_milvus and self._client:
            try:
                col = collection_name or settings.milvus_collection
                search_kwargs = dict(
                    collection_name=col,
                    data=[query_vec],
                    limit=top_k,
                    output_fields=_COLLECTION_FIELDS,
                )
                if subject_filter:
                    search_kwargs["filter"] = f'subject == "{subject_filter}"'

                results = await asyncio.to_thread(self._client.search, **search_kwargs)
                hits = results[0] if results else []
                out = []
                for hit in hits:
                    entity = hit.get("entity", {}) if isinstance(hit, dict) else {}
                    out.append({
                        "book_name": entity.get("book_name"),
                        "edition": entity.get("edition"),
                        "chapter": entity.get("chapter"),
                        "page_number": entity.get("page_number"),
                        "chunk_text": entity.get("chunk_text"),
                        "subject": entity.get("subject"),
                        "part": entity.get("part"),
                        "section": entity.get("section"),
                        "score": 1.0 - float(hit.get("distance", 0.5)) if isinstance(hit, dict) else 0.5,
                    })
                return out
            except Exception as e:  # noqa: BLE001
                log_event(logger, WARNING, "milvus_search_error",
                          trace_id=trace_id, error=type(e).__name__, msg=str(e))
                if not settings.enable_milvus_fallback:
                    raise RetrievalUnavailableError("Milvus 检索失败", trace_id) from e
                self._use_memory = True
        return self._memory.search(query_vec, top_k)

    async def count(self, trace_id: str = "-") -> int:
        use_milvus = await self._ensure_connected()
        if not use_milvus and not settings.enable_milvus_fallback:
            raise RetrievalUnavailableError("Milvus 服务不可用", trace_id)
        if use_milvus and self._client:
            try:
                # 同步 pymilvus 调用放入线程池
                stats = await asyncio.to_thread(
                    self._client.get_collection_stats,
                    settings.milvus_collection,
                )
                return int(stats.get("row_count", 0))
            except Exception as exc:  # noqa: BLE001
                if not settings.enable_milvus_fallback:
                    raise RetrievalUnavailableError("Milvus 状态读取失败", trace_id) from exc
        return self._memory.count()


milvus_service = MilvusService()
