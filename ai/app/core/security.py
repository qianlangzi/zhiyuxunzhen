"""内部接口鉴权（PRD 9.4）

Spring Boot 调用 FastAPI 的所有 /review /embed /learning_path /daily_case /report 接口
必须携带 X-Internal-Token 头，值与 Java 端 zhiyu.ai.internal-token 一致。
"""
from fastapi import Header, HTTPException, status

from app.core.config import settings


def require_internal_token(x_internal_token: str | None = Header(default=None)) -> None:
    """FastAPI 依赖项：校验 X-Internal-Token 头"""
    if not x_internal_token or x_internal_token != settings.internal_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="内部接口鉴权失败：X-Internal-Token 缺失或错误",
        )
