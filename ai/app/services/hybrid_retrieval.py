"""混合检索服务（BM25 稀疏 + Dense 稠密 + RRF 融合 + LLM Reranking）

实验验证（838 chunk 内科学）：
  - 纯 Dense: Top-1 = 100%
  - BM25+RRF: Top-1 = 100%（小数据集无提升，大数据集预期有提升）
  - LLM Reranking: Top-1 = 100%（Top-1 结果更切题，但增加 3-5s 延迟）

设计：
  1. BM25 索引从 Milvus 懒加载，内存缓存（TTL 300s）+ 磁盘持久化（重启不重建）
  2. 入库后调用 bm25_append 增量更新，避免全量重建
  3. 规模上限保护：超过 bm25_max_docs 拒绝构建并降级 dense
  4. RRF 融合 Dense + Sparse 结果（k=60）
  5. LLM Reranking 可选（默认关闭，高精度场景启用）
"""
import asyncio
import hashlib
import json
import os
import pickle
import time
from typing import Any

import jieba
from rank_bm25 import BM25Okapi

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import ERROR, INFO, WARNING

logger = get_logger(__name__)

# BM25 索引缓存: {cache_key: (bm25_index, doc_list, expire_time)}
_BM25_CACHE: dict[str, tuple[BM25Okapi, list[dict], float]] = {}
_CACHE_TTL = 300  # 5 分钟
_DISK_CACHE_MAX_AGE = 24 * 3600  # 磁盘缓存最长 24h，超过强制全量重建


def _tokenize(text: str) -> list[str]:
    """jieba 中文分词，过滤空白和标点"""
    tokens = jieba.lcut(text)
    return [t.strip() for t in tokens if t.strip() and len(t.strip()) > 1]


def _cache_key(collection: str, subject: str | None) -> str:
    return hashlib.md5(f"{collection}:{subject or 'all'}".encode()).hexdigest()


def _disk_cache_path(cache_key: str) -> str:
    return os.path.join(settings.bm25_cache_dir, f"{cache_key}.pkl")


def _build_index(all_docs: list[dict]) -> BM25Okapi:
    tokenized_docs = [_tokenize(doc.get("chunk_text", "")) for doc in all_docs]
    return BM25Okapi(tokenized_docs)


def _persist_to_disk(cache_key: str, bm25: BM25Okapi, docs: list[dict]) -> None:
    """索引 pickle 持久化到磁盘（失败静默，仅影响下次启动速度）"""
    def _write() -> None:
        os.makedirs(settings.bm25_cache_dir, exist_ok=True)
        tmp = _disk_cache_path(cache_key) + ".tmp"
        with open(tmp, "wb") as f:
            pickle.dump({"bm25": bm25, "docs": docs, "built_at": time.time()}, f)
        os.replace(tmp, _disk_cache_path(cache_key))

    try:
        import asyncio as _aio
        loop = _aio.get_running_loop()
        loop.run_in_executor(None, _write)
    except Exception:  # noqa: BLE001
        pass


def _load_from_disk(cache_key: str) -> tuple[BM25Okapi, list[dict]] | None:
    """从磁盘加载索引；不存在 / 过期 / 损坏返回 None"""
    path = _disk_cache_path(cache_key)
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "rb") as f:
            data = pickle.load(f)  # noqa: S301 - 本服务自己写入的缓存文件
        if time.time() - data.get("built_at", 0) > _DISK_CACHE_MAX_AGE:
            return None
        return data["bm25"], data["docs"]
    except Exception:  # noqa: BLE001
        return None


async def build_bm25_index(
    milvus_client,
    collection: str,
    subject: str | None = None,
    trace_id: str = "-",
) -> tuple[BM25Okapi, list[dict]] | None:
    """获取 BM25 索引：内存缓存 → 磁盘缓存 → 从 Milvus 全量构建。

    内存缓存 TTL 5 分钟；磁盘缓存重启后直接加载不重建；
    超过 bm25_max_docs 规模上限时拒绝构建（调用方降级 dense）。
    """
    key = _cache_key(collection, subject)
    now = time.time()

    # 1. 内存缓存
    if key in _BM25_CACHE:
        bm25, docs, expire = _BM25_CACHE[key]
        if now < expire:
            log_event(logger, INFO, "bm25_cache_hit",
                      trace_id=trace_id, cache_key=key[:8], docs=len(docs))
            return bm25, docs

    # 2. 磁盘缓存（重启恢复，无需全量拉取）
    disk = await asyncio.to_thread(_load_from_disk, key)
    if disk is not None:
        bm25, docs = disk
        _BM25_CACHE[key] = (bm25, docs, now + _CACHE_TTL)
        log_event(logger, INFO, "bm25_disk_cache_loaded",
                  trace_id=trace_id, cache_key=key[:8], docs=len(docs))
        return bm25, docs

    # 3. 从 Milvus 拉取所有 chunk（字段名按 collection 实际 schema 解析，兼容实验集合）
    from app.services.milvus_service import milvus_service as _ms

    try:
        schema = await _ms._schema_for(collection, trace_id)
        alias = schema["alias"]
        filter_expr = f'subject == "{subject}"' if subject else 'id != ""'
        # 分页拉取（每次 1000 条）
        all_docs: list[dict] = []
        offset = 0
        while True:
            results = await asyncio.to_thread(
                milvus_client.query,
                collection_name=collection,
                filter=filter_expr,
                output_fields=schema["actual"],
                limit=1000,
                offset=offset,
                timeout=10.0,  # 与 milvus_service._OP_TIMEOUT 一致，防 gRPC 死通道挂起
            )
            data = results if isinstance(results, list) else results.get("data", [])
            if not data:
                break
            # 实际字段名 → 规范字段名（BM25 分词/RRF 融合统一用 chunk_text/id）。
            # 排除向量字段（生产 vector / 实验 dense_embedding），避免 1024 维浮点列表
            # 撑爆内存与磁盘缓存。
            vec_field = schema["vector"]
            all_docs.extend(
                {alias.get(k, k): v for k, v in row.items() if k != vec_field}
                for row in data
            )
            if len(data) < 1000:
                break
            offset += 1000
    except Exception as e:
        log_event(logger, WARNING, "bm25_build_error",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return None

    if not all_docs:
        return None

    # 规模上限保护：超过上限说明数据规模已超出内存 BM25 方案的适用范围
    if len(all_docs) > settings.bm25_max_docs:
        log_event(logger, ERROR, "bm25_scale_limit_exceeded",
                  trace_id=trace_id, docs=len(all_docs),
                  limit=settings.bm25_max_docs,
                  hint="数据规模超过 BM25 内存索引上限，已降级 pure dense；请迁移 Milvus 稀疏向量或 Elasticsearch")
        return None

    # 4. 分词构建 + 双层缓存
    bm25 = await asyncio.to_thread(_build_index, all_docs)
    _BM25_CACHE[key] = (bm25, all_docs, now + _CACHE_TTL)
    _persist_to_disk(key, bm25, all_docs)
    log_event(logger, INFO, "bm25_built",
              trace_id=trace_id, docs=len(all_docs), subject=subject or "all")
    return bm25, all_docs


def bm25_append(
    collection: str,
    subject: str | None,
    new_docs: list[dict],
) -> bool:
    """入库后增量更新 BM25 索引（同步、轻量）。

    内存缓存存在：追加 docs 重建索引（O(n)，入库低频可接受）并持久化；
    内存缓存不存在：删除磁盘缓存，下次查询自动全量重建（包含新数据）。
    """
    if not new_docs:
        return True
    key = _cache_key(collection, subject)

    if key in _BM25_CACHE:
        bm25, docs, expire = _BM25_CACHE[key]
        # 去重：以 id 为主键，重复入库（重灌一本书）时覆盖旧 doc
        new_ids = {d.get("id") for d in new_docs}
        merged = [d for d in docs if d.get("id") not in new_ids] + list(new_docs)
        if len(merged) > settings.bm25_max_docs:
            _BM25_CACHE.pop(key, None)
            try:
                os.remove(_disk_cache_path(key))
            except OSError:
                pass
            return False
        rebuilt = _build_index(merged)
        _BM25_CACHE[key] = (rebuilt, merged, time.time() + _CACHE_TTL)
        _persist_to_disk(key, rebuilt, merged)
        return True

    # 无内存缓存：清掉磁盘缓存，让下次构建带回新数据
    try:
        os.remove(_disk_cache_path(key))
    except OSError:
        pass
    return True


def bm25_invalidate(collection: str, subject: str | None) -> None:
    """失效指定 (collection, subject) 的 BM25 缓存（内存 + 磁盘），下次检索自动重建。

    供分科入库后调用：分科视图依赖重建时的 subject 过滤，无法像全量视图那样增量追加。
    """
    key = _cache_key(collection, subject)
    _BM25_CACHE.pop(key, None)
    try:
        os.remove(_disk_cache_path(key))
    except OSError:
        pass


def bm25_search(
    bm25: BM25Okapi,
    docs: list[dict],
    query: str,
    top_k: int = 20,
) -> list[dict]:
    """BM25 稀疏检索"""
    tokens = _tokenize(query)
    if not tokens:
        return []
    scores = bm25.get_scores(tokens)
    # 取 top_k
    ranked = sorted(enumerate(scores), key=lambda x: x[1], reverse=True)[:top_k]
    results = []
    for idx, score in ranked:
        if score <= 0:
            break
        doc = docs[idx].copy()
        doc["bm25_score"] = float(score)
        results.append(doc)
    return results


def rrf_fusion(
    dense_results: list[dict],
    sparse_results: list[dict],
    k: int = 60,
    top_k: int = 5,
) -> list[dict]:
    """Reciprocal Rank Fusion: 融合 Dense + Sparse 排序结果。

    RRF(d) = Σ 1/(k + rank_i(d))
    """
    scores: dict[str, float] = {}
    doc_map: dict[str, dict] = {}

    for rank, r in enumerate(dense_results):
        doc_id = r.get("id", str(rank))
        scores[doc_id] = scores.get(doc_id, 0) + 1.0 / (k + rank + 1)
        if doc_id not in doc_map:
            doc_map[doc_id] = r

    for rank, r in enumerate(sparse_results):
        doc_id = r.get("id", str(rank))
        scores[doc_id] = scores.get(doc_id, 0) + 1.0 / (k + rank + 1)
        if doc_id not in doc_map:
            doc_map[doc_id] = r

    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)[:top_k]
    results = []
    for doc_id, rrf_score in ranked:
        doc = doc_map[doc_id].copy()
        doc["rrf_score"] = rrf_score
        # 统一 score 为 RRF 分：避免融合结果里余弦分/RRF 分混杂，
        # 展示顺序与分数不一致（余弦分 ~0.9 vs RRF 分 ~0.02 量级不同）
        doc["score"] = rrf_score
        results.append(doc)
    return results


async def llm_rerank(
    query: str,
    candidates: list[dict],
    top_k: int = 5,
    trace_id: str = "-",
) -> list[dict]:
    """LLM Reranking: 用 LLM 对候选结果打分精排。

    需要 LLM 配置，否则直接返回原顺序。
    增加约 3-5s 延迟，仅在高精度场景启用。
    """
    if not settings.llm_configured or not candidates:
        return candidates[:top_k]

    from openai import AsyncOpenAI

    client = AsyncOpenAI(
        base_url=settings.llm_base_url,
        api_key=settings.llm_api_key.get_secret_value(),
        timeout=30.0,
    )

    # 构造评分 prompt
    candidates_text = ""
    for i, c in enumerate(candidates[:10]):  # 最多评分 10 个
        text = c.get("chunk_text", "")[:200].replace("\n", " ")
        candidates_text += f"[{i+1}] {text}\n"

    prompt = (
        f"查询：{query}\n\n"
        f"以下是候选文档片段，请按与查询的相关性打分（0-10分，10分最相关）：\n{candidates_text}\n"
        f"只返回 JSON 数组，格式 [{{\"index\":1,\"score\":9.5}}, ...]，不要其他内容。"
    )

    try:
        resp = await client.chat.completions.create(
            model=settings.llm_model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500,
            temperature=0.1,
        )
        content = resp.choices[0].message.content.strip()
        # 解析 JSON
        import re
        json_match = re.search(r"\[.*\]", content, re.DOTALL)
        if not json_match:
            return candidates[:top_k]
        scores = json.loads(json_match.group())

        # 按分数排序
        scored = []
        for s in scores:
            idx = s.get("index", 0) - 1
            if 0 <= idx < len(candidates):
                doc = candidates[idx].copy()
                doc["rerank_score"] = s.get("score", 0)
                # 统一 score 为 LLM 重排分（0-10），保证展示顺序与分数一致
                doc["score"] = s.get("score", 0)
                scored.append(doc)
        scored.sort(key=lambda x: x.get("rerank_score", 0), reverse=True)
        return scored[:top_k]
    except Exception as e:
        log_event(logger, WARNING, "llm_rerank_error",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return candidates[:top_k]
