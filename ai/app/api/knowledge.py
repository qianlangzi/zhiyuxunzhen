"""受控教材对象的异步入库入口 + 向量检索接口。"""
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from app.core.security import require_internal_token
from app.domain.enums import TaskType
from app.models.common import R, Citation
from app.services.rag_service import rag_service
from app.workers.task_models import TaskEnvelope
from app.workers.task_queue import TaskQueue

router = APIRouter()


class KnowledgeIngestRequest(BaseModel):
    textbookId: int = Field(gt=0)
    objectKey: str = Field(min_length=1, max_length=500)
    bookName: str | None = Field(default=None, max_length=200)
    edition: str | None = Field(default=None, max_length=50)
    subject: str | None = Field(default=None, max_length=128, description="学科标签（内科/心电等），写入 chunk 元数据供分科过滤")
    collectionName: str | None = Field(default=None, max_length=128, description="目标 Milvus collection，不传用默认生产集合")


class KnowledgeSearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=500, description="检索关键词")
    topK: int = Field(default=5, ge=1, le=20, description="返回条数")
    subject: str | None = Field(default=None, max_length=128, description="学科过滤（内科/心电等），不传则不过滤")
    collection: str | None = Field(default=None, max_length=128, description="Milvus collection，不传用默认")
    strategy: str = Field(default="dense", description="检索策略: dense(纯向量) | hybrid(BM25+RRF) | rerank(+LLM重排序)")


@router.post("/knowledge/ingest", response_model=R)
async def ingest_knowledge(
    req: KnowledgeIngestRequest,
    request: Request,
    _token: None = Depends(require_internal_token),
):
    task = await TaskQueue(getattr(request.app.state, "redis_client", None)).enqueue(
        TaskEnvelope(
            idempotency_key=f"knowledge:{req.textbookId}:{req.objectKey}",
            task_type=TaskType.KNOWLEDGE_INGEST,
            payload=req.model_dump(),
        )
    )
    return R(data={"ingestionId": task.task_id, "status": task.status.value})


@router.post("/knowledge/search", response_model=R)
async def search_knowledge(
    req: KnowledgeSearchRequest,
    _token: None = Depends(require_internal_token),
):
    """向量检索教材知识库，支持 subject 学科过滤和多种检索策略。

    检索策略:
      - dense: 纯向量检索（默认，最快 <100ms）
      - hybrid: BM25+Dense RRF 融合（大数据集更优 <200ms）
      - rerank: hybrid + LLM 重排序（高精度 +3-5s）

    返回 data.citations 为 Citation 列表，每条含 book_name/chapter/page/chunk_text/subject/score。
    """
    citations = await rag_service.search(
        query=req.query,
        top_k=req.topK,
        subject=req.subject,
        collection_name=req.collection,
        strategy=req.strategy,
    )
    return R(data={"citations": [c.model_dump() for c in citations]})
