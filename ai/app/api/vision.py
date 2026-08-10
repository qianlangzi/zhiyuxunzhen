"""多模态影像/检验分析（PRD 9.2）

POST /api/v1/ai/vision/analyze
"""
import ipaddress
import uuid
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException, status
from openai import AsyncOpenAI, APIError

from app.core.config import settings
from app.core.logging import get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.models.chat import VisionAnalyzeRequest, VisionAnalysisResult
from app.prompts.templates import vision_agent_prompt
from app.services.backend_client import backend_client
from app.core.security import require_mobile_student

logger = get_logger(__name__)
router = APIRouter()


def _validate_image_url(image_url: str) -> str:
    """Validate provider-facing image URLs before a third party fetches them."""
    parsed = urlparse(image_url)
    hostname = (parsed.hostname or "").lower().rstrip(".")
    if parsed.scheme not in {"http", "https"} or not hostname:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="图片地址必须是 HTTP(S) URL")
    if parsed.username or parsed.password or parsed.fragment:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="图片地址格式不安全")
    if hostname in {"localhost", "localhost.localdomain"} or hostname.endswith(".local"):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="图片地址不允许访问本地网络")
    try:
        address = ipaddress.ip_address(hostname)
    except ValueError:
        address = None
    if address is not None and (address.is_private or address.is_loopback or address.is_link_local or address.is_reserved):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="图片地址不允许访问内网地址")
    if settings.env == "prod":
        allowed = {host.lower().rstrip(".") for host in settings.vision_allowed_hosts}
        if hostname not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                                detail="图片来源不在允许范围内")
        if parsed.scheme != "https":
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                                detail="生产环境图片必须使用 HTTPS")
    return image_url


@router.post("/v1/ai/vision/analyze", response_model=VisionAnalysisResult)
async def vision_analyze(
    req: VisionAnalyzeRequest,
    student_id: int = Depends(require_mobile_student),
):
    trace_id = str(uuid.uuid4())
    set_context(trace_id=trace_id, session_id=str(req.session_id))
    try:
        context = await backend_client.session_context(
            req.session_id, student_id, trace_id=trace_id
        )
        if context is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="问诊会话不存在、已结束或不属于当前学生",
            )
        image_url = req.image_url
        if not settings.vision_configured:
            # 降级模式不读图，无需校验来源；直接返回降级文案
            log_event(logger, INFO, "vision_fallback",
                      trace_id=trace_id, session_id=req.session_id)
            return VisionAnalysisResult(
                finding=(
                    "【降级模式】当前未配置多模态大模型 API Key，无法真实读图。"
                    "请在 .env 中配置 VISION_BASE_URL / VISION_API_KEY 后重试。"
                    "医学免责声明：本系统仅供医学教学训练使用，不具备临床诊疗效力。"
                ),
                citations=[],
                safety_blocked=False,
            )

        image_url = _validate_image_url(req.image_url)

        client = AsyncOpenAI(
            base_url=settings.vision_base_url,
            api_key=settings.vision_api_key.get_secret_value(),
            timeout=30.0,
        )
        bbox_desc = f"学生圈画区域：{req.image_bbox}" if req.image_bbox else "未圈画"
        user_content = [
            {"type": "text", "text": f"{bbox_desc}\n学生备注：{req.student_note or '无'}"},
            {"type": "image_url", "image_url": {"url": image_url}},
        ]
        try:
            resp = await client.chat.completions.create(
                model=settings.vision_model,
                messages=[
                    {"role": "system", "content": vision_agent_prompt()},
                    {"role": "user", "content": user_content},
                ],
                max_tokens=600,
            )
            finding = (resp.choices[0].message.content or "").strip()
            log_event(logger, INFO, "vision_ok",
                      trace_id=trace_id, length=len(finding))
            return VisionAnalysisResult(finding=finding, citations=[], safety_blocked=False)
        except APIError as e:
            log_event(logger, WARNING, "vision_error",
                      trace_id=trace_id, error=type(e).__name__, msg=str(e))
            return VisionAnalysisResult(
                finding=(
                    f"读图失败：{type(e).__name__}。"
                    "请稍后重试或检查 API Key 配置。"
                    "医学免责声明：本系统仅供医学教学训练使用。"
                ),
                citations=[],
                safety_blocked=False,
            )
    finally:
        reset_context()
