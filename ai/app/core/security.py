"""内部接口鉴权（PRD 9.4）

Spring Boot 调用 FastAPI 的所有 /review /embed /learning_path /daily_case /report 接口
必须携带 X-Internal-Token 头，值与 Java 端 zhiyu.ai.internal-token 一致。
"""
from fastapi import Header, HTTPException, status
import jwt

from app.core.config import settings


def require_internal_token(x_internal_token: str | None = Header(default=None)) -> None:
    """FastAPI 依赖项：校验 X-Internal-Token 头"""
    if not x_internal_token or x_internal_token != settings.internal_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="内部接口鉴权失败：X-Internal-Token 缺失或错误",
        )


def require_mobile_student(authorization: str | None = Header(default=None)) -> int:
    """校验 Spring Boot 签发的 access token，返回学生 userId。"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="缺少登录凭证")
    try:
        payload = jwt.decode(
            authorization[7:].strip(),
            settings.jwt_secret,
            algorithms=["HS256"],
        )
        if payload.get("type") != "access" or int(payload.get("role", -1)) != 0:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="仅学生可进入问诊")
        return int(payload["sub"])
    except HTTPException:
        raise
    except (jwt.PyJWTError, KeyError, TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="登录凭证无效或已过期",
        ) from exc
