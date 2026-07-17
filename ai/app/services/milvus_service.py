"""Milvus 向量库封装（PRD 7.3）

特性：
1. 懒连接：首次使用时才尝试连接 Milvus，失败时根据 enable_milvus_fallback 切换内存索引
2. 内存索引使用余弦相似度，结果与 Milvus 近似但仅适合小规模数据
3. collection 自动创建，schema：id / vector / book_name / edition / chapter / page_number / chunk_text
"""
import math
import threading
from typing import Any

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING

logger = get_logger(__name__)

_COLLECTION_FIELDS = ["book_name", "edition", "chapter", "page_number", "chunk_text"]


class _MemoryIndex:
    """内存倒排索引，用于 Milvus 不可用时兜底"""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._records: list[dict[str, Any]] = []  # 每条: {fields..., vector: list[float]}

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

    async def _ensure_connected(self) -> bool:
        """首次使用时尝试连接 Milvus；失败则切到内存模式"""
        if self._connected:
            return not self._use_memory
        if self._use_memory:
            return False
        try:
            # 懒导入，避免 pymilvus 未安装时影响其他模块
            from pymilvus import MilvusClient, DataType  # type: ignore[import-untyped]

            client = MilvusClient(
                uri=f"http://{settings.milvus_host}:{settings.milvus_port}"
            )
            # 触发实际连接
            client.list_collections()
            self._client = client
            self._connected = True
            await self._ensure_collection(DataType)
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

    async def _ensure_collection(self, DataType: Any) -> None:
        """若 collection 不存在则创建"""
        if not self._client:
            return
        name = settings.milvus_collection
        if name in self._client.list_collections():
            return
        schema = self._client.create_schema(
            auto_id=False, enable_dynamic_field=False
        )
        schema.add_field("id", DataType.VARCHAR, is_primary=True, max_length=64)
        schema.add_field("vector", DataType.FLOAT_VECTOR, dim=settings.milvus_vector_dim)
        schema.add_field("book_name", DataType.VARCHAR, max_length=200)
        schema.add_field("edition", DataType.VARCHAR, max_length=50)
        schema.add_field("chapter", DataType.VARCHAR, max_length=200)
        schema.add_field("page_number", DataType.INT64)
        schema.add_field("chunk_text", DataType.VARCHAR, max_length=4000)
        index_params = self._client.prepare_index_params()
        index_params.add_index(
            field_name="vector", index_type="AUTOINDEX", metric_type="COSINE"
        )
        self._client.create_collection(
            collection_name=name, schema=schema, index_params=index_params
        )
        log_event(logger, INFO, "milvus_collection_created", name=name)

    async def upsert(
        self,
        records: list[dict[str, Any]],
        trace_id: str = "-",
    ) -> int:
        """插入或更新向量记录。records 字段：id / vector / book_name / edition / chapter / page_number / chunk_text"""
        if not records:
            return 0
        use_milvus = await self._ensure_connected()
        if use_milvus and self._client:
            try:
                self._client.upsert(
                    collection_name=settings.milvus_collection, data=records
                )
                log_event(logger, INFO, "milvus_upsert_ok",
                          trace_id=trace_id, count=len(records))
                return len(records)
            except Exception as e:  # noqa: BLE001
                log_event(logger, WARNING, "milvus_upsert_error",
                          trace_id=trace_id, error=type(e).__name__, msg=str(e))
                if not settings.enable_milvus_fallback:
                    return 0
                self._use_memory = True
        # 内存 fallback
        return self._memory.upsert(records)

    async def search(
        self,
        query_vec: list[float],
        top_k: int = 5,
        trace_id: str = "-",
    ) -> list[dict[str, Any]]:
        """向量相似度检索，返回 top_k 条带 score 的记录"""
        use_milvus = await self._ensure_connected()
        if use_milvus and self._client:
            try:
                results = self._client.search(
                    collection_name=settings.milvus_collection,
                    data=[query_vec],
                    limit=top_k,
                    output_fields=_COLLECTION_FIELDS,
                )
                # Milvus 返回结构：[[{id, distance, entity:{...}}]]
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
                        "score": 1.0 - float(hit.get("distance", 0.5)) if isinstance(hit, dict) else 0.5,
                    })
                return out
            except Exception as e:  # noqa: BLE001
                log_event(logger, WARNING, "milvus_search_error",
                          trace_id=trace_id, error=type(e).__name__, msg=str(e))
                if not settings.enable_milvus_fallback:
                    return []
                self._use_memory = True
        return self._memory.search(query_vec, top_k)

    async def count(self, trace_id: str = "-") -> int:
        use_milvus = await self._ensure_connected()
        if use_milvus and self._client:
            try:
                stats = self._client.get_collection_stats(settings.milvus_collection)
                return int(stats.get("row_count", 0))
            except Exception:  # noqa: BLE001
                pass
        return self._memory.count()


milvus_service = MilvusService()
