"""多模态影像/检验分析（PRD 9.2）

POST /api/v1/ai/vision/analyze
"""
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from openai import AsyncOpenAI, APIError

from app.core.config import settings
from app.core.logging import ensure_trace_id, get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.vision_guard import validate_image_url
from app.models.chat import VisionAnalyzeRequest, VisionAnalysisResult
from app.prompts.templates import vision_agent_prompt
from app.services.backend_client import backend_client
from app.core.security import require_mobile_student

logger = get_logger(__name__)
router = APIRouter()

# 校验逻辑已抽到 app.core.vision_guard（备课素材描述链路共用同一套来源白名单）；
# 这里保留原名转发，兼容既有回归测试与诊断探针的导入路径。
_validate_image_url = validate_image_url


@router.post("/v1/ai/vision/analyze", response_model=VisionAnalysisResult)
async def vision_analyze(
    req: VisionAnalyzeRequest,
    student_id: int = Depends(require_mobile_student),
):
    trace_id = ensure_trace_id()
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
                status="DEGRADED",
                source="NONE",
                degraded=True,
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
                status="FAILED",
                source="NONE",
                degraded=True,
            )
    finally:
        reset_context()
