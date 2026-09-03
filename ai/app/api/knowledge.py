"""受控教材对象的异步入库入口 + 向量检索接口。"""
import base64
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import Response
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
    attemptKey: str | None = Field(default=None, max_length=64, description="重试令牌：业务中台每次触发生成，重试时传新值以绕过幂等去重，确保「失败重试/重新入库」真正重新执行")


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
    queue = TaskQueue(getattr(request.app.state, "redis_client", None))
    # 幂等键：同一 (textbookId, objectKey, attemptKey) 仅入队一次；
    # 业务中台每次「重试/重新入库」生成新的 attemptKey，旧任务即使迟到回调也会被后端按 ingestionId 丢弃。
    attempt_key = (req.attemptKey or "v1").strip()[:64]
    idempotency_key = f"knowledge:{req.textbookId}:{req.objectKey}:{attempt_key}"
    # 任务 ID 在入队前就写入 payload，避免 worker 抢跑时发出无 ingestionId 的回调。
    # traceId 让入库任务的日志可跨 AI/后端/管理端贯穿追踪（此前恒为 "-" 无法排障）。
    task = TaskEnvelope(
        idempotency_key=idempotency_key,
        task_type=TaskType.KNOWLEDGE_INGEST,
        payload={**req.model_dump(), "ingestionId": None, "traceId": str(uuid.uuid4())},
    )
    task.payload["ingestionId"] = task.task_id
    task = await queue.enqueue(task)
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


class ImageSearchRequest(BaseModel):
    imageBase64: str = Field(min_length=16, description="图片 base64（data URI 前缀可选）")
    text: str | None = Field(default=None, max_length=200, description="可选文本描述/上下文")
    topK: int = Field(default=5, ge=1, le=20, description="返回条数")
    subject: str | None = Field(default=None, max_length=128, description="学科过滤（内科/心电等），不传则不过滤")
    traceId: str | None = Field(default=None, description="链路追踪 ID（可选）")


@router.post("/knowledge/search-image", response_model=R)
async def search_knowledge_by_image(
    req: ImageSearchRequest,
    _token: None = Depends(require_internal_token),
):
    """以图搜图：多模态 embedding 检索教材影像知识库。

    输入医学图片（base64），返回相似教材片段（含 image_key 供回显原图 + 教材溯源）。
    返回 data.citations 为 Citation 列表，每条含 book_name/chapter/page/chunk_text/subject/score/image_key。
    """
    raw = req.imageBase64
    if "," in raw[:64]:
        raw = raw.split(",", 1)[1]  # 去掉 data:image/...;base64, 前缀
    try:
        image_bytes = base64.b64decode(raw)
    except Exception:
        raise HTTPException(status_code=422, detail="图片 base64 解码失败")
    if not image_bytes:
        raise HTTPException(status_code=422, detail="图片内容为空")

    citations = await rag_service.search_by_image(
        image_bytes=image_bytes,
        text=req.text or "",
        top_k=req.topK,
        trace_id=req.traceId or str(uuid.uuid4()),
        subject=req.subject,
    )
    return R(data={"citations": [c.model_dump() for c in citations]})


@router.get("/images/{image_key}", response_model=None)
async def get_image(
    image_key: str,
    _token: None = Depends(require_internal_token),
):
    """按 image_key 返回教材图片字节（业务中台/前端回显原图用）。"""
    from app.services.image_index_service import image_index_service

    image_bytes = await image_index_service.read(image_key)
    if image_bytes is None:
        raise HTTPException(status_code=404, detail="图片不存在")
    ext = image_key.rsplit(".", 1)[-1].lower()
    mime = "image/png" if ext == "png" else "image/jpeg"
    return Response(content=image_bytes, media_type=mime)
