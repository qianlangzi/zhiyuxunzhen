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

    async def search(
        self,
        query: str,
        top_k: int = 5,
        trace_id: str = "-",
        subject: str | None = None,
        collection_name: str | None = None,
        strategy: str = "dense",
    ) -> list[Citation]:
        """检索教材，返回 Citation 列表。

        Args:
            subject: 学科过滤（如 "内科"/"心电"），None 表示不过滤
            collection_name: 指定 Milvus collection，None 用默认
            strategy: 检索策略
                - "dense": 纯向量检索（默认，最快）
                - "hybrid": BM25 + Dense RRF 融合（大数据集更优）
                - "rerank": hybrid + LLM 重排序（高精度，+3-5s 延迟）
        """
        if not query.strip():
            return []
        vec = await self.embed(query, trace_id)
        col = collection_name or settings.milvus_collection

        if strategy == "dense":
            hits = await milvus_service.search(
                vec, top_k=top_k, trace_id=trace_id,
                subject_filter=subject,
                collection_name=collection_name,
            )
        elif strategy in ("hybrid", "rerank"):
            # Dense 检索 top-20
            dense_hits = await milvus_service.search(
                vec, top_k=20, trace_id=trace_id,
                subject_filter=subject,
                collection_name=collection_name,
            )

            # BM25 稀疏检索 top-20
            from app.services.hybrid_retrieval import build_bm25_index, bm25_search, rrf_fusion
            bm25_result = await build_bm25_index(
                milvus_service._client, col, subject, trace_id,
            )
            if bm25_result:
                bm25_idx, docs = bm25_result
                sparse_hits = bm25_search(bm25_idx, docs, query, top_k=20)
                # RRF 融合
                hits = rrf_fusion(dense_hits, sparse_hits, k=60, top_k=20)
            else:
                # BM25 不可用，降级为纯 Dense
                log_event(logger, WARNING, "hybrid_fallback_dense",
                          trace_id=trace_id, reason="bm25_unavailable")
                hits = dense_hits[:top_k]

            if strategy == "rerank" and settings.llm_configured:
                from app.services.hybrid_retrieval import llm_rerank
                hits = await llm_rerank(query, hits, top_k=top_k, trace_id=trace_id)
            else:
                hits = hits[:top_k]
        else:
            hits = await milvus_service.search(
                vec, top_k=top_k, trace_id=trace_id,
                subject_filter=subject,
                collection_name=collection_name,
            )

        citations = [
            Citation(
                book_name=h.get("book_name") or "",
                edition=h.get("edition"),
                chapter=h.get("chapter"),
                page_number=h.get("page_number"),
                chunk_text=(h.get("chunk_text") or "")[:500],
                subject=h.get("subject"),
                score=h.get("score") or h.get("rrf_score") or h.get("rerank_score"),
            )
            for h in hits
            if h.get("book_name") or h.get("chunk_text")
        ]
        log_event(logger, INFO, "rag_search",
                  trace_id=trace_id, query_len=len(query),
                  hits=len(citations), subject=subject, strategy=strategy)
        return citations


rag_service = RagService()
