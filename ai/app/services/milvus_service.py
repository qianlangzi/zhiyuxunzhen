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
from logging import ERROR, INFO, WARNING
from app.core.errors import RetrievalUnavailableError

logger = get_logger(__name__)

_COLLECTION_FIELDS = ["id", "book_name", "edition", "chapter", "page_number", "chunk_text", "subject", "part", "section"]

# 实验 collection（zhiyu_ecg/zhiyu_multi）使用了简写字段名，与生产 schema 共存：
# 实际字段名 → 规范字段名（检索/过滤/出参统一走规范名）
_FIELD_ALIASES = {"text": "chunk_text", "book": "book_name", "page": "page_number", "dense_embedding": "vector"}

# pymilvus 2.4 构造参数的 timeout 只作用于建连，操作级超时必须逐调用显式传递；
# 不传 timeout 时 gRPC 在 Milvus 重启后会在死通道上无限挂起（/health/ready 卡死根因）
_OP_TIMEOUT = 10.0


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
        self._degraded_since: float | None = None
        self._degraded_reason: str = ""
        self._memory_empty_warned = False
        self._schema_fields: dict[str, dict[str, Any]] = {}  # collection → schema 信息缓存
        self._last_recovery_attempt: float = 0.0  # 降级恢复试探时间戳

    def _connect_sync(self) -> bool:
        """同步连接 Milvus 并确保 collection 存在（在线程池中执行）"""
        from pymilvus import MilvusClient, DataType  # type: ignore[import-untyped]

        client = MilvusClient(uri=f"http://{settings.milvus_host}:{settings.milvus_port}", timeout=_OP_TIMEOUT)
        client.list_collections(timeout=_OP_TIMEOUT)
        self._client = client

        # 确保 collection 存在
        name = settings.milvus_collection
        if name not in client.list_collections(timeout=_OP_TIMEOUT):
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
                collection_name=name, schema=schema, index_params=index_params,
                timeout=_OP_TIMEOUT,
            )
            log_event(logger, INFO, "milvus_collection_created", name=name)

        return True

    async def _ensure_connected(self) -> bool:
        """首次使用时尝试连接 Milvus；失败则切到内存模式。

        - 连接带 3 次重试（Docker 网络下 gRPC 握手偶发超时，非服务不可用）
        - 降级后每 60s 试探恢复，避免一次抖动导致进程生命周期内永久降级
        """
        if self._connected and self._client is not None and not self._use_memory:
            return True
        if self._use_memory:
            import time as _time
            now = _time.time()
            if now - self._last_recovery_attempt < 60:
                return False
            self._last_recovery_attempt = now
        try:
            last_exc: Exception | None = None
            for attempt in range(1, 4):
                try:
                    # 同步 pymilvus 调用放入线程池，不阻塞事件循环
                    await asyncio.to_thread(self._connect_sync)
                    last_exc = None
                    break
                except Exception as e:  # noqa: BLE001
                    last_exc = e
                    if attempt < 3:
                        await asyncio.sleep(1.5 * attempt)
            if last_exc is not None:
                raise last_exc
            self._connected = True
            if self._use_memory:
                self._use_memory = False
                self._degraded_since = None
                self._degraded_reason = ""
                log_event(logger, INFO, "milvus_recovered",
                          hint="Milvus 连接已恢复，退出内存降级模式")
            else:
                log_event(logger, INFO, "milvus_connected",
                          host=settings.milvus_host, port=settings.milvus_port)
            return True
        except Exception as e:  # noqa: BLE001
            self._use_memory = settings.enable_milvus_fallback
            self._connected = True
            if self._use_memory:
                # 显式告警：降级到内存索引后检索结果是"假可用"（重启即空），必须让运维看见
                import time as _time
                self._degraded_since = _time.time()
                self._degraded_reason = f"{type(e).__name__}: {e}"
                log_event(logger, ERROR, "milvus_degraded_to_memory",
                          error=type(e).__name__, msg=str(e),
                          hint="Milvus 不可用已降级内存索引：重启后索引为空，检索将返回空结果，请尽快恢复 Milvus")
            else:
                log_event(logger, WARNING, "milvus_unavailable",
                          error=type(e).__name__, msg=str(e),
                          fallback=False)
            return False

    def _reset_client(self, op: str = "-") -> None:
        """丢弃死连接（Milvus 重启后旧 gRPC 通道不可复用），下次调用自动重建"""
        if self._client is not None:
            self._client = None
            self._connected = False
            log_event(logger, INFO, "milvus_client_reset", op=op,
                      hint="连接已重置，下次调用将重建 gRPC 通道")

    def status(self) -> dict[str, Any]:
        """当前 Milvus 连接/降级状态（供 /status 与 /ready 暴露）"""
        return {
            "mode": "memory" if self._use_memory else ("milvus" if self._client else "unconnected"),
            "degraded": self._use_memory,
            "degraded_since": self._degraded_since,
            "degraded_reason": self._degraded_reason or None,
        }

    async def upsert(
        self,
        records: list[dict[str, Any]],
        trace_id: str = "-",
        collection_name: str | None = None,
    ) -> int:
        """插入或更新向量记录。

        records 使用规范字段名（chunk_text/book_name/...）；
        目标 collection 为实验 schema（text/book/...）时自动按实际字段名映射。
        """
        if not records:
            return 0
        use_milvus = await self._ensure_connected()
        if not use_milvus and not settings.enable_milvus_fallback:
            raise RetrievalUnavailableError("Milvus 服务不可用", trace_id)
        if use_milvus and self._client:
            col = collection_name or settings.milvus_collection
            try:
                data = await self._map_records_for_collection(records, col, trace_id)
                # 同步 pymilvus 调用放入线程池
                await asyncio.to_thread(
                    self._client.upsert,
                    collection_name=col,
                    data=data,
                    timeout=_OP_TIMEOUT,
                )
                log_event(logger, INFO, "milvus_upsert_ok",
                          trace_id=trace_id, count=len(records), collection=col)
                return len(records)
            except Exception as e:  # noqa: BLE001
                msg = str(e)
                log_event(logger, WARNING, "milvus_upsert_error",
                          trace_id=trace_id, error=type(e).__name__, msg=msg)
                if not settings.enable_milvus_fallback:
                    self._reset_client("upsert")
                    raise RetrievalUnavailableError("Milvus 写入失败", trace_id) from e
                if "not exist" in msg or "not found" in msg or "dim" in msg.lower():
                    # schema/维度类错误：切内存索引会造成数据丢失（内存不持久），直接抛出
                    raise RetrievalUnavailableError(f"Milvus 写入失败: {msg[:200]}", trace_id) from e
                self._reset_client("upsert")
                self._degrade(type(e).__name__, msg, "upsert")
        # 内存 fallback
        return self._memory.upsert(records)

    async def _map_records_for_collection(
        self,
        records: list[dict[str, Any]],
        collection: str,
        trace_id: str,
    ) -> list[dict[str, Any]]:
        """入库前把规范字段名映射为目标 collection 的实际字段名。

        兼容实验 schema（text/book/page/dense_embedding）：目标 collection
        缺失的字段（如实验集合无 part/section）直接丢弃，避免 upsert 报
        field not exist。
        """
        schema = await self._schema_for(collection, trace_id)
        # 规范名 → 实际名（schema["alias"] 是 {实际: 规范}，反转即得）
        rev = {v: k for k, v in schema["alias"].items()}
        allowed = set(schema["actual"])  # 目标 collection 实际存在的非向量字段（含别名与同名规范字段）
        out: list[dict[str, Any]] = []
        for r in records:
            row: dict[str, Any] = {}
            for k, v in r.items():
                if k == "vector":
                    row[schema["vector"]] = v
                elif k in rev and rev[k] in allowed:
                    row[rev[k]] = v
                elif k in allowed:
                    row[k] = v
                # 其余字段（目标 collection 不存在）丢弃
            out.append(row)
        return out

    def _degrade(self, error: str, msg: str, op: str) -> None:
        """运行中从 Milvus 降级到内存索引：显式 ERROR 告警并记录降级状态"""
        import time as _time
        if not self._use_memory:
            self._use_memory = True
            self._degraded_since = _time.time()
            self._degraded_reason = f"{error} (during {op}): {msg}"
            log_event(logger, ERROR, "milvus_degraded_to_memory",
                      error=error, msg=msg, op=op,
                      hint="已降级内存索引，检索/写入结果不可靠，请尽快恢复 Milvus")

    async def _schema_for(self, collection: str, trace_id: str = "-") -> dict[str, Any]:
        """解析 collection 的实际 schema，兼容实验/生产两种字段命名。

        旧 collection（实验脚本建的 zhiyu_ecg/zhiyu_multi）字段名为
        text/book/page/dense_embedding，直接按生产字段名请求会抛
        field not exist 或取值全 None；此处 describe 一次并缓存：
          actual: 实际存在的输出字段名（用于 output_fields）
          alias:  {实际字段名: 规范字段名}（用于取值映射）
          vector: 向量字段名（用于 anns_field）
        """
        if collection in self._schema_fields:
            return self._schema_fields[collection]
        if self._client is None:
            raise RetrievalUnavailableError(
                f"Milvus 未连接，无法解析 collection schema: {collection}", trace_id,
            )
        desc = await asyncio.to_thread(
            self._client.describe_collection, collection, timeout=_OP_TIMEOUT
        )
        fields = desc.get("fields", [])
        names = {f.get("name") for f in fields}
        vec_fields = [
            f.get("name") for f in fields
            if str(f.get("type")) == "101" or f.get("type") == 101
        ]

        actual: list[str] = []
        alias: dict[str, str] = {}
        for canon in _COLLECTION_FIELDS:
            if canon in names:
                actual.append(canon)
                alias[canon] = canon
                continue
            for a, c in _FIELD_ALIASES.items():
                if c == canon and a in names:
                    actual.append(a)
                    alias[a] = canon
                    break

        info = {
            "actual": actual,
            "alias": alias,
            "vector": vec_fields[0] if vec_fields else "vector",
        }
        self._schema_fields[collection] = info
        log_event(logger, INFO, "milvus_schema_resolved",
                  trace_id=trace_id, collection=collection,
                  fields=len(actual), vector_field=info["vector"])
        return info

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
                schema = await self._schema_for(col, trace_id)
                actual_fields = schema["actual"]
                alias = schema["alias"]
                search_kwargs = dict(
                    collection_name=col,
                    data=[query_vec],
                    limit=top_k,
                    output_fields=actual_fields,
                    timeout=_OP_TIMEOUT,
                )
                # 实验集合向量字段名为 dense_embedding，需显式指定
                if schema["vector"] != "vector":
                    search_kwargs["anns_field"] = schema["vector"]
                if subject_filter and "subject" in actual_fields:
                    search_kwargs["filter"] = f'subject == "{subject_filter}"'

                results = await asyncio.to_thread(self._client.search, **search_kwargs)
                hits = results[0] if results else []
                out = []
                for hit in hits:
                    entity = hit.get("entity", {}) if isinstance(hit, dict) else {}
                    # 实际字段名 → 规范字段名（实验 schema text→chunk_text 等）
                    mapped = {alias.get(k, k): v for k, v in entity.items()}
                    out.append({
                        "id": mapped.get("id") or (hit.get("id") if isinstance(hit, dict) else None),
                        "book_name": mapped.get("book_name"),
                        "edition": mapped.get("edition"),
                        "chapter": mapped.get("chapter"),
                        "page_number": mapped.get("page_number"),
                        "chunk_text": mapped.get("chunk_text"),
                        "subject": mapped.get("subject"),
                        "part": mapped.get("part"),
                        "section": mapped.get("section"),
                        "score": 1.0 - float(hit.get("distance", 0.5)) if isinstance(hit, dict) else 0.5,
                    })
                return out
            except Exception as e:  # noqa: BLE001
                msg = str(e)
                log_event(logger, WARNING, "milvus_search_error",
                          trace_id=trace_id, error=type(e).__name__, msg=msg)
                if not settings.enable_milvus_fallback:
                    self._reset_client("search")
                    raise RetrievalUnavailableError("Milvus 检索失败", trace_id) from e
                if "not exist" in msg or "not found" in msg:
                    # schema/参数类错误：切内存索引毫无意义（结果必然为空），直接抛出让调用方感知
                    raise RetrievalUnavailableError(f"Milvus 检索失败: {msg[:200]}", trace_id) from e
                self._reset_client("search")
                self._degrade(type(e).__name__, msg, "search")
        results = self._memory.search(query_vec, top_k)
        if not results and not self._memory_empty_warned:
            self._memory_empty_warned = True
            log_event(logger, WARNING, "milvus_memory_index_empty",
                      trace_id=trace_id,
                      hint="内存索引为空：服务重启后内存索引不持久，请恢复 Milvus 后重新入库")
        return results

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
                    timeout=_OP_TIMEOUT,
                )
                return int(stats.get("row_count", 0))
            except Exception as exc:  # noqa: BLE001
                if not settings.enable_milvus_fallback:
                    self._reset_client("count")
                    raise RetrievalUnavailableError("Milvus 状态读取失败", trace_id) from exc
                self._reset_client("count")
        return self._memory.count()


milvus_service = MilvusService()
