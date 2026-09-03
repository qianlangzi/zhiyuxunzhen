"""RAG 检索服务（PRD 7.3）

职责：
1. 调用 Embedding 服务把文本转向量
   - 优先使用 DashScope Qwen3-VL-Embedding（多模态，实验验证 100% Top-1）
   - 降级使用 OpenAI 兼容协议（纯文本 bge-m3 等）
2. 调用 Milvus 做相似度检索
3. 把检索结果封装为 Citation 列表
4. 凭证未配置时抛出 RetrievalUnavailableError，不伪造零向量结果
"""
import base64
import os

import httpx
from openai import AsyncOpenAI, APIError

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.models.common import Citation
from app.services.milvus_service import milvus_service
from app.core.errors import RetrievalUnavailableError

logger = get_logger(__name__)


class RagService:
    """教材知识库 RAG"""

    def __init__(self) -> None:
        self._embed_client: AsyncOpenAI | None = None
        if settings.embedding_configured:
            self._embed_client = AsyncOpenAI(
                base_url=settings.embedding_base_url,
                api_key=settings.embedding_api_key.get_secret_value(),
                timeout=30.0,
            )
        # DashScope 多模态 embedding 客户端
        self._use_dashscope = settings.dashscope_configured
        if self._use_dashscope:
            self._ds_endpoint = (
                f"{settings.dashscope_base_url.rstrip('/')}"
                "/services/embeddings/multimodal-embedding/multimodal-embedding"
            )
            self._ds_api_key = settings.dashscope_api_key.get_secret_value()

    @property
    def available(self) -> bool:
        return self._embed_client is not None or self._use_dashscope

    def rebuild(self) -> None:
        """按当前 settings 重建客户端（供 ModelRegistry 热切换模型时调用）"""
        self._embed_client = None
        if settings.embedding_configured:
            self._embed_client = AsyncOpenAI(
                base_url=settings.embedding_base_url,
                api_key=settings.embedding_api_key.get_secret_value(),
                timeout=30.0,
            )
        self._use_dashscope = settings.dashscope_configured
        if self._use_dashscope:
            self._ds_endpoint = (
                f"{settings.dashscope_base_url.rstrip('/')}"
                "/services/embeddings/multimodal-embedding/multimodal-embedding"
            )
            self._ds_api_key = settings.dashscope_api_key.get_secret_value()

    # ============================================================
    # DashScope Qwen3-VL-Embedding（多模态，实验验证最优）
    # ============================================================
    async def embed_multimodal(
        self, text: str, image_path: str | None = None, trace_id: str = "-",
        max_retries: int = 3,
    ) -> list[float]:
        """DashScope 多模态 embedding：文本+图片融合为单一向量。

        优先使用此方法。当 image_path 存在且文件可读时，附加图片一起 embedding。
        包含 3 次重试 + 指数退避（实验验证的网络容错策略）。
        """
        if not self._use_dashscope:
            return await self.embed(text, trace_id)

        content: dict = {"text": text}
        if image_path and os.path.exists(image_path):
            ext = os.path.splitext(image_path)[1].lower().lstrip(".")
            mime = "image/png" if ext == "png" else "image/jpeg"
            with open(image_path, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("utf-8")
            content["image"] = f"data:{mime};base64,{b64}"

        payload = {
            "model": settings.dashscope_embedding_model,
            "input": {"contents": [content]},
            "parameters": {
                "enable_fusion": True,
                "dimension": settings.dashscope_embedding_dim,
            },
        }

        import asyncio as _aio
        last_err = None
        for attempt in range(1, max_retries + 1):
            try:
                async with httpx.AsyncClient(timeout=120.0) as client:
                    resp = await client.post(
                        self._ds_endpoint,
                        headers={
                            "Authorization": f"Bearer {self._ds_api_key}",
                            "Content-Type": "application/json",
                        },
                        json=payload,
                    )
                    resp.raise_for_status()
                    data = resp.json()
                    return data["output"]["embeddings"][0]["embedding"]
            except Exception as e:
                last_err = e
                if attempt < max_retries:
                    wait = 2 ** attempt  # 2s, 4s, 8s
                    log_event(logger, WARNING, "dashscope_embed_retry",
                              trace_id=trace_id, attempt=attempt, wait=wait,
                              error=type(e).__name__)
                    await _aio.sleep(wait)

        log_event(logger, WARNING, "dashscope_embed_error",
                  trace_id=trace_id, attempts=max_retries,
                  error=type(last_err).__name__, msg=str(last_err))
        raise RetrievalUnavailableError("DashScope Embedding 调用失败", trace_id) from last_err

    # ============================================================
    # 旧：OpenAI 兼容协议（纯文本，降级用）
    # ============================================================
    async def embed(self, text: str, trace_id: str = "-") -> list[float]:
        """纯文本转向量（OpenAI 兼容协议）；不可用时抛出 RetrievalUnavailableError"""
        if not self.available:
            raise RetrievalUnavailableError("Embedding 服务未配置", trace_id)
        if self._use_dashscope and not self._embed_client:
            # 只有 DashScope，走多模态接口（纯文本模式）
            return await self.embed_multimodal(text, None, trace_id)
        if not self._embed_client:
            raise RetrievalUnavailableError("Embedding 服务未配置", trace_id)
        try:
            resp = await self._embed_client.embeddings.create(
                model=settings.embedding_model, input=text
            )
            return resp.data[0].embedding
        except APIError as e:
            log_event(logger, WARNING, "embed_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            raise RetrievalUnavailableError("Embedding 服务调用失败", trace_id) from e

    async def embed_batch(
        self, texts: list[str], trace_id: str = "-",
    ) -> list[list[float]]:
        """批量 embedding（DashScope 不支持批量，逐条调用）"""
        if not texts:
            return []
        if self._use_dashscope:
            return [await self.embed_multimodal(t, None, trace_id) for t in texts]
        if not self._embed_client:
            raise RetrievalUnavailableError("Embedding 服务未配置", trace_id)
        try:
            resp = await self._embed_client.embeddings.create(
                model=settings.embedding_model, input=texts
            )
            return [d.embedding for d in resp.data]
        except APIError as e:
            log_event(logger, WARNING, "embed_batch_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            raise RetrievalUnavailableError("Embedding 服务调用失败", trace_id) from e

    async def embed_multimodal_batch(
        self,
        items: list[tuple[str, str | None]],
        trace_id: str = "-",
        concurrency: int | None = None,
    ) -> list[list[float] | None]:
        """批量多模态 embedding（并发池，结果与输入顺序一致）。

        DashScope 不支持批量接口，原逐条串行一本书要上千次往返；
        此处用 semaphore 并发（默认 settings.embed_concurrency），失败项返回 None
        由调用方决定跳过/重试。

        Args:
            items: [(text, image_path), ...]
        """
        import asyncio as _aio

        sem = _aio.Semaphore(concurrency or settings.embed_concurrency)

        async def _one(text: str, image_path: str | None) -> list[float] | None:
            async with sem:
                try:
                    return await self.embed_multimodal(text, image_path, trace_id)
                except Exception:  # noqa: BLE001 - 单条失败不拖垮整批
                    return None

        return list(await _aio.gather(*[_one(t, p) for t, p in items]))

    async def _search_once(
        self,
        query: str,
        top_k: int,
        trace_id: str,
        subject: str | None,
        collection_name: str | None,
        strategy: str,
    ) -> tuple[list[dict], float | None]:
        """单轮检索（dense / hybrid / rerank 三策略）。

        返回 (hits, dense_top1_score)：dense_top1 是向量通道 top1 余弦分。
        三种策略统一用它衡量检索质量（hybrid 的 RRF 分 / rerank 的 LLM 分
        与余弦分量级不同，不可直接比较），供自适应迭代检索判断是否重查。
        """
        vec = await self.embed(query, trace_id)
        col = collection_name or settings.milvus_collection

        if strategy == "dense":
            hits = await milvus_service.search(
                vec, top_k=top_k, trace_id=trace_id,
                subject_filter=subject,
                collection_name=collection_name,
            )
            top1 = float(hits[0]["score"]) if hits and hits[0].get("score") is not None else None
            return hits, top1
        if strategy in ("hybrid", "rerank"):
            # Dense 检索与 BM25 构建/稀疏检索互相独立，并发执行：
            # 冷启动（BM25 首次构建数万条）较长，串行会多等一个长尾；
            # 命中磁盘缓存时 BM25 很快，dense 成为主导，并发收益同样为正。
            import asyncio as _aio
            from app.services.hybrid_retrieval import (
                build_bm25_index, bm25_search, rrf_fusion,
            )

            async def _sparse():
                bm25_result = await build_bm25_index(
                    milvus_service._client, col, subject, trace_id,
                )
                if bm25_result:
                    bm25_idx, docs = bm25_result
                    return bm25_search(bm25_idx, docs, query, top_k=20)
                return None

            dense_hits, sparse_hits = await _aio.gather(
                milvus_service.search(
                    vec, top_k=20, trace_id=trace_id,
                    subject_filter=subject, collection_name=collection_name,
                ),
                _sparse(),
            )
            dense_top1 = (
                float(dense_hits[0]["score"])
                if dense_hits and dense_hits[0].get("score") is not None else None
            )

            if sparse_hits is not None:
                # RRF 融合（k=60 与既往一致）
                hits = rrf_fusion(dense_hits, sparse_hits, k=60, top_k=20)
            else:
                # BM25 不可用（含构建失败/规模超限），降级为纯 Dense
                log_event(logger, WARNING, "hybrid_fallback_dense",
                          trace_id=trace_id, reason="bm25_unavailable")
                hits = dense_hits[:top_k]

            if strategy == "rerank" and settings.llm_configured:
                from app.services.hybrid_retrieval import llm_rerank
                hits = await llm_rerank(query, hits, top_k=top_k, trace_id=trace_id)
            else:
                hits = hits[:top_k]
            return hits, dense_top1
        hits = await milvus_service.search(
            vec, top_k=top_k, trace_id=trace_id,
            subject_filter=subject,
            collection_name=collection_name,
        )
        top1 = float(hits[0]["score"]) if hits and hits[0].get("score") is not None else None
        return hits, top1

    async def search(
        self,
        query: str,
        top_k: int | None = None,
        trace_id: str = "-",
        subject: str | None = None,
        collection_name: str | None = None,
        strategy: str | None = None,
        rewrite: bool = False,
        history: list[dict[str, str]] | None = None,
    ) -> list[Citation]:
        """检索教材，返回 Citation 列表。

        Args:
            subject: 学科过滤（如 "内科"/"心电"），None 表示不过滤
            collection_name: 指定 Milvus collection，None 用默认
            strategy: 检索策略
                - "dense": 纯向量检索（默认，最快）
                - "hybrid": BM25 + Dense RRF 融合（大数据集更优）
                - "rerank": hybrid + LLM 重排序（高精度，+3-5s 延迟）
            rewrite: 检索前做 LLM 查询改写（口语→术语 + 指代消解）
            history: 多轮对话历史（rewrite 指代消解用），如 [{"role","content"}]

        top_k/strategy 未显式传参时回退到 settings.rag_top_k / settings.rag_strategy
        （由 AI 配置中心热同步的 RAG 运行参数覆盖，保证管理端配置真正生效）。
        """
        query = query.strip()
        if not query:
            return []

        # 未显式传参 → 读取配置中心热同步的运行参数（管理端可一键改默认检索行为）
        if top_k is None:
            top_k = int(getattr(settings, "rag_top_k", 5) or 5)
        if strategy is None:
            strategy = str(getattr(settings, "rag_strategy", "dense") or "dense")
        if strategy not in ("dense", "hybrid", "rerank"):
            log_event(logger, WARNING, "rag_strategy_invalid",
                      trace_id=trace_id, strategy=strategy, fallback="dense")
            strategy = "dense"
        # 下界/上界保护：配置 0/负数会导致 Milvus 检索报错，过大值拖慢延迟，统一收敛
        if top_k < 1:
            log_event(logger, WARNING, "rag_top_k_invalid",
                      trace_id=trace_id, top_k=top_k, fallback=5)
            top_k = 5
        if top_k > 50:
            log_event(logger, WARNING, "rag_top_k_clamped",
                      trace_id=trace_id, top_k=top_k, clamped=50)
            top_k = 50

        # ---- 查询改写（口语→医学术语 + 指代消解）----
        effective_query = query
        if rewrite:
            from app.services.query_rewriting import rewrite_query
            effective_query = await rewrite_query(query, history=history, trace_id=trace_id)

        # ---- 第一轮检索 ----
        hits, dense_top1 = await self._search_once(
            effective_query, top_k, trace_id, subject, collection_name, strategy,
        )

        # ---- 自适应迭代检索：向量通道 top1 分数低 → 用"另一形态的 query"重查一轮并融合 ----
        # dense/hybrid/rerank 三种策略统一用向量余弦分判断（RRF/LLM 分量级不同）。
        # 修复"条件限制"：原逻辑在 rewrite=True（生产主路径）时 retry_query 恒等于
        # effective_query，导致迭代检索永不触发。正确做法是对着还没试过的形态重试：
        #   首轮用改写 R 且 R != 原句   → 补一轮原始 query；
        #   首轮用原句（未改写/改写无变化）→ 补一轮改写 query。
        # LRU 缓存已保证 rewrite_query 重复调用命中，不会为本流程引入多余 LLM 调用。
        if (
            settings.iterative_search_enabled
            and hits
            and dense_top1 is not None
            and dense_top1 < settings.iterative_score_threshold
        ):
            from app.services.query_rewriting import rewrite_query
            retry_query = (
                query if effective_query != query          # 已试改写 R，改试原句
                else await rewrite_query(query, history=history, trace_id=trace_id)
            )  # 已试原句，改写重试；同句重搜无意义（LRU 也只会给回原句）
            if retry_query and retry_query != effective_query:
                try:
                    second, _ = await self._search_once(
                        retry_query, top_k, trace_id, subject, collection_name, strategy,
                    )
                except Exception as e:  # noqa: BLE001 - 重查失败不丢弃已就绪的首轮结果
                    log_event(logger, WARNING, "iterative_retry_failed",
                              trace_id=trace_id, error=type(e).__name__)
                    second = []
                if second:
                    # 简单去重后融合：第二轮结果按 score 降序补进第一轮
                    seen = {h.get("id") for h in hits if h.get("id")}
                    merged = hits + [h for h in second
                                     if not h.get("id") or h.get("id") not in seen]
                    merged.sort(key=lambda h: h.get("score") or 0, reverse=True)
                    hits = merged[:top_k]
                    log_event(logger, INFO, "iterative_search_fused",
                              trace_id=trace_id, dense_top1=round(dense_top1, 3),
                              strategy=strategy, retry_query=retry_query[:50])

        # ---- 附加图片映射（生成侧多模态）----
        image_keys: dict[int, str] = {}
        try:
            from app.services.image_index_service import image_index_service
            for i, h in enumerate(hits):
                if h.get("id"):
                    key = await image_index_service.lookup(str(h["id"]))
                    if key:
                        image_keys[i] = key
        except Exception:  # noqa: BLE001 - 图片映射失败不影响检索结果
            pass

        citations = [
            Citation(
                book_name=h.get("book_name") or "",
                edition=h.get("edition"),
                chapter=h.get("chapter"),
                page_number=h.get("page_number"),
                chunk_text=(h.get("chunk_text") or "")[: settings.citation_max_chars],
                subject=h.get("subject"),
                score=h.get("score") or h.get("rrf_score") or h.get("rerank_score"),
                image_key=image_keys.get(i),
            )
            for i, h in enumerate(hits)
            if h.get("book_name") or h.get("chunk_text")
        ]
        log_event(logger, INFO, "rag_search",
                  trace_id=trace_id, query_len=len(query),
                  hits=len(citations), subject=subject, strategy=strategy,
                  rewritten=effective_query != query,
                  with_images=len(image_keys))
        return citations

    async def search_by_image(
        self,
        image_bytes: bytes,
        text: str = "",
        top_k: int = 5,
        trace_id: str = "-",
        subject: str | None = None,
    ) -> list[Citation]:
        """以图搜图：用多模态 embedding 把图片（+可选文本）转成向量后检索教材。

        与 search() 的差异：query 不是文本而是图片。命中结果同样带 image_key
        （前端可回显教材原图）与教材溯源。
        """
        # 1. 把图片 bytes 落到临时文件（embed_multimodal 需要本地路径）
        import tempfile

        ext = "png"
        if not text.strip():
            text = "这是一张医学教材图片，请检索教材中相关的知识内容。"
        with tempfile.NamedTemporaryFile(suffix=f".{ext}", delete=False) as tmp:
            tmp.write(image_bytes)
            tmp_path = tmp.name
        try:
            vec = await self.embed_multimodal(text, tmp_path, trace_id)
        finally:
            try:
                os.remove(tmp_path)
            except OSError:
                pass

        # 2. 向量检索（dense，直接复用 milvus）
        hits = await milvus_service.search(
            vec, top_k=top_k, trace_id=trace_id,
            subject_filter=subject,
        )

        # 3. 附加图片映射
        image_keys: dict[int, str] = {}
        try:
            from app.services.image_index_service import image_index_service
            for i, h in enumerate(hits):
                if h.get("id"):
                    key = await image_index_service.lookup(str(h["id"]))
                    if key:
                        image_keys[i] = key
        except Exception:  # noqa: BLE001
            pass

        citations = [
            Citation(
                book_name=h.get("book_name") or "",
                edition=h.get("edition"),
                chapter=h.get("chapter"),
                page_number=h.get("page_number"),
                chunk_text=(h.get("chunk_text") or "")[: settings.citation_max_chars],
                subject=h.get("subject"),
                score=h.get("score") or h.get("rrf_score") or h.get("rerank_score"),
                image_key=image_keys.get(i),
            )
            for i, h in enumerate(hits)
            if h.get("book_name") or h.get("chunk_text")
        ]
        log_event(logger, INFO, "rag_search_image",
                  trace_id=trace_id, hits=len(citations), subject=subject,
                  with_images=len(image_keys))
        return citations


rag_service = RagService()
