"""大模型能力集成用例（真实调用，默认跳过）

覆盖深度思考模型（DeepSeek V4.1 Flash）在项目链路上的四项关键行为，
防止「换模型 / 改预算」这类无感的线上事故再次发生：

1. ``chat_json`` 默认关闭思维链 —— 结构化输出不会被思维链挤掉正文
2. 旧模型名 ``deepseek-v4-flash`` 仍被官方接受并路由到 V4.1 Flash
3. 多模态读图（Vision）可用
4. ``resolve_tools`` 回传 ``reasoning_content`` 后工具调用能收敛

**默认跳过**（会真实消耗 token，需联网 + 有效 Key）。运行方式：

```bash
# 容器内（WORKDIR=/app，env 已注入 LLM_* / DEEPSEEK_*）
RUN_LLM_INTEGRATION=1 python -m pytest tests/integration -q

# 或本机指定模型
RUN_LLM_INTEGRATION=1 LLM_BASE_URL=https://api.deepseek.com/v1 \
  LLM_API_KEY=sk-xxx LLM_MODEL=deepseek-flash \
  python -m pytest tests/integration -q
```

历史背景（2026-09-10）：
- 官方将模型名统一为 ``deepseek-flash``（= DeepSeek-V4.1-Flash，1M 上下文，支持 Vision）。
  旧名 ``deepseek-v4-flash`` 对应模型已下线，请求由 V4.1-Flash 服务并按 Flash 计费。
- 思维链与正文共享同一份 ``max_tokens``：预算被思考吃光时 ``finish_reason=length``
  且 ``content`` 为空，结构化 JSON 必然解析失败（线上导师提示为空即此因）。
- 携带 ``tools`` 的请求必须完整回传 ``reasoning_content``，否则模型无法接续推理，
  会重复发起同一个工具调用而不收敛。
"""
import base64
import json
import os
import struct
import zlib

import pytest

from app.core.config import settings
from app.services.llm_client import llm_client

_RUN = os.getenv("RUN_LLM_INTEGRATION") == "1"

pytestmark = pytest.mark.skipif(
    not _RUN,
    reason="集成用例需真实 API：设置 RUN_LLM_INTEGRATION=1 才会运行",
)

LEGACY_MODEL = "deepseek-v4-flash"  # 官方仍接受，由 V4.1-Flash 提供服务


@pytest.fixture(autouse=True)
def _require_configured_llm():
    """未配置 LLM 时跳过而非误报失败（llm_client.available=False 会走规则降级）。"""
    if not llm_client.available:
        pytest.skip("LLM 未配置（LLM_BASE_URL / LLM_API_KEY 缺失）")


# ---------------------------------------------------------------------------
# 辅助：生成一张纯色 PNG，避免测试依赖仓库里的图片资源
# （仓库中部分 png 被 BOM 污染，第三方多模态接口会 400 拒收）
# ---------------------------------------------------------------------------
def _make_png(r: int, g: int, b: int, size: int = 64) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        payload = tag + data
        return (
            struct.pack(">I", len(data))
            + payload
            + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)
        )

    raw = b"".join(b"\x00" + bytes([r, g, b]) * size for _ in range(size))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


class _TextbookTool:
    """最小可用工具桩，满足 LlmClient.resolve_tools 的协议要求。"""

    name = "search_textbook"

    def schema(self) -> dict:
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": "检索教材内容",
                "parameters": {
                    "type": "object",
                    "properties": {"q": {"type": "string"}},
                    "required": ["q"],
                },
            },
        }

    async def run(self, args: dict, trace_id: str = "-") -> str:
        return "教材摘要：肺炎是肺泡的炎症，常见表现为发热、咳嗽、咳痰。"


# ---------------------------------------------------------------------------
# 用例
# ---------------------------------------------------------------------------
async def test_chat_json_returns_parsed_json_without_thinking():
    """chat_json 默认关思维链：正文必须是可直接解析的 JSON 且非空。

    若思维链未关闭，max_tokens 会被推理过程吃掉，表现为
    ``finish_reason=length`` + 空正文，结构化解析必然失败。
    """
    result = await llm_client.chat_json(
        [
            {"role": "system", "content": "你是医学教学助手，只输出 JSON。"},
            {"role": "user", "content": '返回 {"dx":"肺炎","confidence":0.9}，字段名必须是 dx/confidence。'},
        ],
        max_tokens=512,
        trace_id="it-json",
    )
    assert isinstance(result, dict), f"结构化输出不是 dict: {result!r}"
    assert result.get("dx"), f"JSON 缺少 dx 字段（可能被思维链截断）: {result!r}"


async def test_legacy_model_name_is_routed_to_flash():
    """旧名 deepseek-v4-flash 仍可用，且由 V4.1-Flash 实际服务。

    响应里的 model 字段会回 `deepseek-flash`，这正是「官方已路由」的证据。
    """
    resp = await llm_client._client.chat.completions.create(
        model=LEGACY_MODEL,
        messages=[{"role": "user", "content": "回复两个字：你好"}],
        max_tokens=32,
        extra_body={"thinking": {"type": "disabled"}},
    )
    assert resp.choices[0].message.content, "旧模型名返回空正文"
    assert "flash" in (resp.model or "").lower(), (
        f"旧模型名未被路由到 Flash 系列，实际 model={resp.model!r}"
    )


async def test_vision_reads_inline_image():
    """多模态读图：base64 内联 PNG 必须被正确识别。

    请求体格式与官方 Vision 文档一致，项目侧零结构改动即可支持多模态。
    """
    b64 = base64.b64encode(_make_png(220, 30, 30)).decode()
    resp = await llm_client._client.chat.completions.create(
        model=settings.llm_model,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "这张图片是什么颜色？只回答一个颜色词。"},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                ],
            }
        ],
        max_tokens=64,
        extra_body={"thinking": {"type": "disabled"}},
    )
    answer = (resp.choices[0].message.content or "").strip()
    assert answer, "多模态返回空正文"
    assert "红" in answer, f"模型未识别出红色，实际回答: {answer!r}"


async def test_tool_call_converges_after_reasoning_passthrough():
    """resolve_tools 回传 reasoning_content 后，工具调用必须收敛。

    回归防护：修复前模型拿不到上一轮推理，会重复发起同一个工具调用，
    表现为 messages 里出现两次及以上 role=tool 的结果。
    """
    messages = [{"role": "user", "content": "帮我查一下肺炎的教材内容"}]
    result = await llm_client.resolve_tools(
        messages,
        [_TextbookTool()],
        trace_id="it-tools",
        max_steps=3,
    )
    tool_turns = [m for m in result if m.get("role") == "tool"]
    assert len(tool_turns) < 2, (
        f"工具调用未收敛（重复调用 {len(tool_turns)} 次），"
        "请检查 assistant 消息是否回传了 reasoning_content"
    )
    # 回传生效时，assistant 消息上应能看到思维链字段
    assert any(
        m.get("role") == "assistant" and m.get("reasoning_content")
        for m in result
    ) or not tool_turns, "未观察到 reasoning_content 回传"
