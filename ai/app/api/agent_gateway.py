"""统一 Agent 网关（阶段3）：``POST /internal/agent/{code}``

把散点 AI 调用收敛为 6 个 Agent 分组接口，配合管理端「Agent 定义」(AgentSpec)：
- 取 ``GROUPS[code]`` 内置定义 → ``config_center.resolve_agent_spec`` 合并热配
- 复用现有 endpoint 请求模型 + 处理函数，零业务重写
- 未知分组 404 / 未知 action 400 / 请求体校验失败 422
"""
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, ValidationError
from sse_starlette.sse import EventSourceResponse

from app.agents.gateway_features import (
    FEATURES,
    GROUPS,
    default_action_for,
)
from app.core.logging import set_agent_sampling
from app.core.security import require_internal_token
from app.services.config_center import config_center

router = APIRouter()


class AgentGatewayRequest(BaseModel):
    """网关统一请求体：action 选择分组内能力，task 透传给现有 handler。"""

    action: str | None = None
    task: dict[str, Any] = Field(default_factory=dict)
    options: dict[str, Any] = Field(default_factory=dict)


@router.post("/internal/agent/{code}")
async def agent_gateway(
    code: str,
    body: AgentGatewayRequest,
    _t: None = Depends(require_internal_token),
):
    default_spec = GROUPS.get(code)
    if default_spec is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"未知的 Agent 分组: {code}")

    spec = config_center.resolve_agent_spec(code, default_spec)
    # 管理端停用的分组：网关级优雅降级，不进入 handler，避免误用已停能力
    if not spec.enabled:
        return {
            "code": 0,
            "data": {"status": "DEGRADED", "degraded": True, "reason": "agent_disabled"},
        }

    actions = FEATURES.get(code) or {}
    action = body.action or default_action_for(code)
    if action is None or action not in actions:
        available = "、".join(sorted(actions)) or "无"
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"分组 {code} 无 action: {body.action}（可用: {available}）",
        )

    feat = actions[action]

    # `options.stream` 是告知性信号：流式与否以 action 注册的 is_stream 为准。
    # 若调用方显式指定且与该动作不符（如给同步动作传 stream=true），说明上层
    # 运输方式与能力语义矛盾，尽早 400 拦截，避免把「误配」伪装成静默降级。
    if body.options.get("stream") is not None:
        requested_stream = bool(body.options.get("stream"))
        if requested_stream != feat.is_stream:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"action {code}.{action} 是{'流式' if feat.is_stream else '同步'}能力，"
                    f"options.stream 与之一致应为 {str(feat.is_stream).lower()}"
                ),
            )

    try:
        model = feat.model(**body.task)
    except ValidationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=e.errors()) from None

    # 直接复用现有 handler，返回其原样 R / EventSourceResponse。
    # 先按解析出的 AgentSpec 写入采样上下文，让「AI 配置中心」热改的
    # temperature/max_tokens/model 真正作用到本次调用；handler 返回后清除。
    set_agent_sampling(spec.temperature, spec.max_tokens, spec.model)
    try:
        resp = await feat.handler(model, None)
    except BaseException:
        set_agent_sampling(None, None, None)
        raise

    # 流式动作：handler 返回的 EventSourceResponse 其生成器体在「响应发送阶段」
    # 才真正执行（llm 调用发生在生成器内）。此时上面的 set 在 handler return 后
    # 若立即清除，采样上下文会先于生成器执行被清空，导致流式热配静默失效。
    # 因此把采样注入包裹进生成器：在迭代流的同时保持 Agent 采样上下文可见，
    # 流结束/中断时再清除，且不会串扰并发请求（ContextVar 按 asyncio Task 隔离）。
    if feat.is_stream and isinstance(resp, EventSourceResponse):
        upstream = resp.body_iterator
        agree = (spec.temperature, spec.max_tokens, spec.model)

        async def _wrapped_stream():
            try:
                set_agent_sampling(*agree)
                async for chunk in upstream:
                    yield chunk
            finally:
                set_agent_sampling(None, None, None)

        resp.body_iterator = _wrapped_stream()
        return resp

    set_agent_sampling(None, None, None)
    return resp