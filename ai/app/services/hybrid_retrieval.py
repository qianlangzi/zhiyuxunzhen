"""混合检索服务（BM25 稀疏 + Dense 稠密 + RRF 融合 + LLM Reranking）

实验验证（838 chunk 内科学）：
  - 纯 Dense: Top-1 = 100%
  - BM25+RRF: Top-1 = 100%（小数据集无提升，大数据集预期有提升）
  - LLM Reranking: Top-1 = 100%（Top-1 结果更切题，但增加 3-5s 延迟）

设计：
  1. BM25 索引从 Milvus 懒加载，内存缓存（TTL 300s）
  2. RRF 融合 Dense + Sparse 结果（k=60）
  3. LLM Reranking 可选（默认关闭，高精度场景启用）
"""
import asyncio
import hashlib
import json
import time
from typing import Any

import jieba
from rank_bm25 import BM25Okapi

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING

logger = get_logger(__name__)

# BM25 索引缓存: {cache_key: (bm25_index, doc_list, expire_time)}
_BM25_CACHE: dict[str, tuple[BM25Okapi, list[dict], float]] = {}
_CACHE_TTL = 300  # 5 分钟


def _tokenize(text: str) -> list[str]:
    """jieba 中文分词，过滤空白和标点"""
    tokens = jieba.lcut(text)
    return [t.strip() for t in tokens if t.strip() and len(t.strip()) > 1]


def _cache_key(collection: str, subject: str | None) -> str:
    return hashlib.md5(f"{collection}:{subject or 'all'}".encode()).hexdigest()


async def build_bm25_index(
    milvus_client,
    collection: str,
    subject: str | None = None,
    trace_id: str = "-",
) -> tuple[BM25Okapi, list[dict]] | None:
    """从 Milvus 拉取所有 chunk 文本，构建 BM25 索引。

    索引缓存在内存中，TTL 5 分钟。
    """
    key = _cache_key(collection, subject)
    now = time.time()

    # 检查缓存
    if key in _BM25_CACHE:
        bm25, docs, expire = _BM25_CACHE[key]
        if now < expire:
            log_event(logger, INFO, "bm25_cache_hit",
                      trace_id=trace_id, cache_key=key[:8], docs=len(docs))
            return bm25, docs

    # 从 Milvus 拉取所有 chunk
    filter_expr = f'subject == "{subject}"' if subject else ""
    try:
        # 分页拉取（每次 1000 条）
        all_docs: list[dict] = []
        offset = 0
        while True:
            results = await asyncio.to_thread(
                milvus_client.query,
                collection_name=collection,
                filter=filter_expr or "page_number >= 0",
                output_fields=["id", "chunk_text", "book_name", "chapter",
                               "page_number", "subject", "part", "section"],
                limit=1000,
                offset=offset,
            )
            data = results if isinstance(results, list) else results.get("data", [])
            if not data:
                break
            all_docs.extend(data)
            if len(data) < 1000:
                break
            offset += 1000
    except Exception as e:
        log_event(logger, WARNING, "bm25_build_error",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return None

    if not all_docs:
        return None

    # 分词并构建 BM25 索引
    tokenized_docs = [_tokenize(doc.get("chunk_text", "")) for doc in all_docs]
    bm25 = BM25Okapi(tokenized_docs)

    # 缓存
    _BM25_CACHE[key] = (bm25, all_docs, now + _CACHE_TTL)
    log_event(logger, INFO, "bm25_built",
              trace_id=trace_id, docs=len(all_docs), subject=subject or "all")
    return bm25, all_docs


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
                scored.append(doc)
        scored.sort(key=lambda x: x.get("rerank_score", 0), reverse=True)
        return scored[:top_k]
    except Exception as e:
        log_event(logger, WARNING, "llm_rerank_error",
                  trace_id=trace_id, error=type(e).__name__, msg=str(e))
        return candidates[:top_k]
