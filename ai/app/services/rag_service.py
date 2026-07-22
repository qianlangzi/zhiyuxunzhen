"""RAG 检索服务（PRD 7.3）

职责：
1. 调用 Embedding 服务把文本转向量（OpenAI 兼容协议）
2. 调用 Milvus 做相似度检索
3. 把检索结果封装为 Citation 列表
4. 凭证未配置时返回空溯源，不阻塞主流程
"""
from openai import AsyncOpenAI, APIError

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING
from app.models.common import Citation
from app.services.milvus_service import milvus_service
from app.core.errors import RetrievalUnavailableError

logger = get_logger(__name__)

# Embedding 不可用时，返回与配置维度相同的零向量，使 Milvus 检索仍可执行（结果为空）
_ZERO_VEC: list[float] | None = None


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

    @property
    def available(self) -> bool:
        return self._embed_client is not None

    async def embed(self, text: str, trace_id: str = "-") -> list[float]:
        """文本转向量；不可用时返回零向量"""
        if not self.available:
            if settings.enable_milvus_fallback:
                return _zero_vector()
            raise RetrievalUnavailableError("Embedding 服务未配置", trace_id)
        try:
            resp = await self._embed_client.embeddings.create(
                model=settings.embedding_model, input=text
            )
            return resp.data[0].embedding
        except APIError as e:
            log_event(logger, WARNING, "embed_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            if settings.enable_milvus_fallback:
                return _zero_vector()
            raise RetrievalUnavailableError("Embedding 服务调用失败", trace_id) from e

    async def embed_batch(
        self, texts: list[str], trace_id: str = "-"
    ) -> list[list[float]]:
        """批量 embedding，单条失败不影响整体"""
        if not texts:
            return []
        if not self.available:
            if settings.enable_milvus_fallback:
                return [_zero_vector() for _ in texts]
            raise RetrievalUnavailableError("Embedding 服务未配置", trace_id)
        try:
            resp = await self._embed_client.embeddings.create(
                model=settings.embedding_model, input=texts
            )
            # OpenAI 兼容接口返回顺序与输入一致
            return [d.embedding for d in resp.data]
        except APIError as e:
            log_event(logger, WARNING, "embed_batch_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            if settings.enable_milvus_fallback:
                return [_zero_vector() for _ in texts]
            raise RetrievalUnavailableError("Embedding 服务调用失败", trace_id) from e

    async def search(
        self,
        query: str,
        top_k: int = 5,
        trace_id: str = "-",
    ) -> list[Citation]:
        """检索教材，返回 Citation 列表"""
        if not query.strip():
            return []
        vec = await self.embed(query, trace_id)
        hits = await milvus_service.search(vec, top_k=top_k, trace_id=trace_id)
        citations = [
            Citation(
                book_name=h.get("book_name") or "",
                edition=h.get("edition"),
                chapter=h.get("chapter"),
                page_number=h.get("page_number"),
                chunk_text=(h.get("chunk_text") or "")[:500],
            )
            for h in hits
            if h.get("book_name")
        ]
        log_event(logger, INFO, "rag_search",
                  trace_id=trace_id, query_len=len(query), hits=len(citations))
        return citations


def _zero_vector() -> list[float]:
    global _ZERO_VEC
    if _ZERO_VEC is None:
        _ZERO_VEC = [0.0] * settings.milvus_vector_dim
    return _ZERO_VEC


rag_service = RagService()
