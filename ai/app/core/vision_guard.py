"""交给第三方多模态服务前，对图片 URL 做来源校验（问诊读图 / 备课素材共用）。

生产环境的安全边界：只允许从白名单主机抓图，且协议必须与白名单声明一致。

白名单条目**自带协议**（语义取自运维的显式声明）：
  - 裸主机名 ``storage.example.com``   → 仅允许 https（安全默认）
  - 完整 URL ``http://8.160.161.158`` → 允许 http（自建对象存储只有 IP+HTTP
    入口、无证书时的合法场景）

这样既修掉了「白名单写成完整 URL 却永远匹配不上」的 403，也不必在校验侧硬编码
『生产必须 HTTPS』，避免把合法的 HTTP 图床一并拦死。未写协议一律按 https 处理，
安全边界不放松。

本模块从 ``app.api.vision`` 抽出（2026-09-11）：备课素材描述链路此前只校验 scheme，
把任意 URL 交给第三方 VLM 抓取，与问诊读图的安全边界不一致。
"""
import ipaddress
from urllib.parse import urlparse

from fastapi import HTTPException, status

from app.core.config import settings


def validate_image_url(image_url: str) -> str:
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
    if address is not None and (address.is_private or address.is_loopback
                                or address.is_link_local or address.is_reserved):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="图片地址不允许访问内网地址")
    if settings.env == "prod":
        allowed_schemes = settings.vision_allowed_origins.get(hostname)
        if not allowed_schemes:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                                detail="图片来源不在允许范围内")
        if parsed.scheme not in allowed_schemes:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                                detail="图片来源协议不被允许")
    return image_url
