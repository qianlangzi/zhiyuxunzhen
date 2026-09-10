"""Vision 路由端到端集成用例（真实模型调用，默认跳过）。

针对 2026-09-10 线上缺陷「病例问诊图片发不出去」：
  白名单写成 ``http://8.160.161.158``（带协议），而校验侧按裸主机名比较 → 恒 403。

本文件按**线上同款配置**（ENV_MODE=prod + 白名单条目自带协议）打真实 HTTP 路由，
验证：
  1. 白名单命中的来源可以走完整路由完成一次**真实读图**（不再 403）；
  2. 白名单之外的主机仍然被 403 拦下（安全边界未被放松）。

运行方式（容器内，真实消耗 token）：

```bash
docker cp ai/tests/. zhiyu-ai:/app/tests/
docker exec -e no_proxy='*' -e PYTHONPATH=/app -e RUN_LLM_INTEGRATION=1 \
  -w /app zhiyu-ai python -m pytest tests/integration/test_vision_e2e.py -q
```
"""
from __future__ import annotations

import os

import httpx
import pytest

from app.core.config import settings
from app.main import app

_RUN = os.getenv("RUN_LLM_INTEGRATION") == "1"

pytestmark = pytest.mark.skipif(
    not _RUN,
    reason="端到端用例需真实多模态 API：设置 RUN_LLM_INTEGRATION=1 才会运行",
)

# 探针图片：阿里云 OSS 官方示例图，MaaS 网关可直取（避免依赖仓库图片资源）
PUBLIC_IMG = os.getenv(
    "PROBE_IMAGE_URL",
    "https://dashscope.oss-cn-beijing.aliyuncs.com/images/dog_and_girl.jpeg",
)
PUBLIC_HOST = "dashscope.oss-cn-beijing.aliyuncs.com"


@pytest.fixture(autouse=True)
def _require_vision():
    if not settings.vision_configured:
        pytest.skip("Vision 未配置（VISION_BASE_URL / VISION_API_KEY 缺失）")


def _client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    )


async def test_vision_end_to_end_under_prod_whitelist(
    monkeypatch, student_jwt_token, mock_backend_client
):
    """线上同款配置下，白名单来源可完成真实读图（修复前是 403）。"""
    monkeypatch.setattr(settings, "env", "prod")
    monkeypatch.setattr(
        settings, "vision_allowed_hosts", [f"https://{PUBLIC_HOST}"]
    )

    async with _client() as c:
        resp = await c.post(
            "/v1/ai/vision/analyze",
            json={"session_id": 1, "image_url": PUBLIC_IMG,
                  "student_note": "读一下这张图"},
            headers={"Authorization": student_jwt_token},
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["finding"].strip(), f"读图结论为空：{data}"
    assert not data.get("degraded"), f"落入降级：{data}"
    assert "NONE" not in str(data.get("source", "")), data


async def test_vision_rejects_host_outside_whitelist(
    monkeypatch, student_jwt_token, mock_backend_client
):
    """白名单之外的来源必须继续 403，不能被这次修复顺手放开。"""
    monkeypatch.setattr(settings, "env", "prod")
    monkeypatch.setattr(settings, "vision_allowed_hosts", ["https://storage.example.com"])

    async with _client() as c:
        resp = await c.post(
            "/v1/ai/vision/analyze",
            json={"session_id": 1, "image_url": PUBLIC_IMG},
            headers={"Authorization": student_jwt_token},
        )

    assert resp.status_code == 403, resp.text
