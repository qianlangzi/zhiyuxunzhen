"""多模态影像/检验分析（PRD 9.2）

两个入口，走同一套业务逻辑：

- ``POST /v1/ai/vision/analyze``    公网/移动端直连，学生身份取自移动端 JWT
- ``POST /internal/vision/analyze`` 业务中台调用，``X-Internal-Token`` 鉴权，
  学生身份取自请求体 ``student_id``（Spring Boot 已用移动端 JWT 鉴权并注入 UserContext）

设计说明（2026-09-11）：此前读图是后端**唯一**直接把「移动端 JWT」转发给 AI 做鉴权的
端点（其余 chat / companion 都走 ``/internal/*`` + ``X-Internal-Token``）。这条跨系统
凭证耦合一旦任一环节漂移（token 过期 / 密钥不一致 / 头丢失），症状统一退化成
「读图服务暂不可用」，排查成本极高。现在后端改走内部端点，凭证不再跨系统传递；
归属校验仍由 ``backend_client.session_context()`` 二次完成，安全边界不变。
"""
from fastapi import APIRouter, Depends, HTTPException, status
from openai import AsyncOpenAI, APIError

from app.core.config import settings
from app.core.logging import ensure_trace_id, get_logger, log_event, set_context, reset_context
from logging import INFO, WARNING
from app.core.security import require_internal_token, require_mobile_student
from app.core.vision_guard import validate_image_url
from app.models.chat import VisionAnalyzeRequest, VisionAnalysisResult
from app.prompts.templates import vision_agent_prompt
from app.services.backend_client import backend_client

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
    """移动端直连读图：学生身份只认 JWT，忽略请求体里的 student_id。"""
    return await _run_vision_analyze(req, student_id)


@router.post("/internal/vision/analyze", response_model=VisionAnalysisResult)
async def vision_analyze_internal(
    req: VisionAnalyzeRequest,
    _t: None = Depends(require_internal_token),
):
    """内部读图（Spring Boot 调用，X-Internal-Token 鉴权）。"""
    if req.student_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="内部读图必须提供 student_id",
        )
    return await _run_vision_analyze(req, req.student_id)


async def _run_vision_analyze(req: VisionAnalyzeRequest, student_id: int) -> VisionAnalysisResult:
    """读图核心逻辑：会话归属校验 → 来源白名单校验 → 调 VLM → 结构化结果。"""
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
