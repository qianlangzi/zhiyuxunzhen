"""多模态链路探针 —— 实测四条链路 + 复现/验证 vision 白名单缺陷。

链路对照：
  ① 问诊  app/api/vision.py            -> settings.vision_model (VISION 槽位)
  ② 学伴  app/workflows/companion_*    -> model_gateway.stream -> 主 LLM (LLM 槽位, 思考开启)
  ③ 备课  app/api/lesson.py            -> settings.vision_model (VISION 槽位)
  ④ 索引  app/services/image_index_*   -> settings.vision_model (VISION 槽位, base64 内联)

容器内运行：
  docker cp ai/tests/vision_probe.py zhiyu-ai:/app/tests/vision_probe.py
  docker exec -e no_proxy='*' -e PYTHONPATH=/app -w /app zhiyu-ai python tests/vision_probe.py
"""
from __future__ import annotations

import asyncio
import base64
import os
import sys
import traceback

from openai import AsyncOpenAI

from app.core.config import settings

PUBLIC_IMG = os.getenv(
    "PROBE_IMAGE_URL",
    "https://dashscope.oss-cn-beijing.aliyuncs.com/images/dog_and_girl.jpeg",
)
TIMEOUT = 90.0

RESULTS: list[tuple[str, bool, str]] = []
_B64_CACHE: dict[str, str] = {}


def _rec(name: str, ok: bool, detail: str, expectation: bool | None = None) -> None:
    """expectation=None 时按「实测即通过」判定；给定值时按「实测 == 期望值」判定，
    用于把「故意复现的已知缺陷」标记为预期结果而不是失败。"""
    passed = ok if expectation is None else (ok == expectation)
    RESULTS.append((name, passed, detail))
    print(f"\n[{'PASS' if passed else 'FAIL'}] {name}\n      {detail}", flush=True)


def _client(base_url: str, api_key: str) -> AsyncOpenAI:
    return AsyncOpenAI(base_url=base_url, api_key=api_key, timeout=TIMEOUT)


async def _fetch_base64(url: str) -> str:
    """把公网图片抓成 data URI，避免依赖供应商侧抓取。"""
    if url in _B64_CACHE:
        return _B64_CACHE[url]
    import httpx

    async with httpx.AsyncClient(timeout=30.0, trust_env=False, follow_redirects=True) as h:
        r = await h.get(url)
        r.raise_for_status()
        mime = r.headers.get("content-type", "image/jpeg").split(";")[0]
        uri = f"data:{mime};base64,{base64.b64encode(r.content).decode()}"
    _B64_CACHE[url] = uri
    return uri


async def _raw_read(client: AsyncOpenAI, model: str, img: str, tag: str,
                    max_tokens: int, disable_thinking: bool = False) -> tuple[str, str]:
    kwargs: dict[str, object] = {}
    if disable_thinking:
        kwargs["extra_body"] = {"thinking": {"type": "disabled"}}
    resp = await client.chat.completions.create(
        model=model,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": "用一句话描述这张图里有什么。"},
                {"type": "image_url", "image_url": {"url": img}},
            ],
        }],
        max_tokens=max_tokens,
        **kwargs,
    )
    msg = resp.choices[0].message
    text = (msg.content or "").strip()
    reasoning = getattr(msg, "reasoning_content", None) or ""
    usage = getattr(resp, "usage", None)
    tok = getattr(usage, "total_tokens", "?") if usage else "?"
    finish = resp.choices[0].finish_reason
    print(f"      [{tag}] model={resp.model} finish={finish} tokens={tok} "
          f"reasoning_len={len(reasoning)} content_len={len(text)}", flush=True)
    print(f"      [{tag}] content={text[:180]!r}", flush=True)
    return text, f"finish={finish} tokens={tok} reasoning={len(reasoning)}字 content={len(text)}字"


# ---------------------------------------------------------------- 链路② 学伴
async def t_companion_real() -> None:
    """学伴真实链路：model_gateway.stream(agent_code='companion')，思考开启、预算 2048"""
    name = "T1 学伴真实链路 · model_gateway.stream 带图"
    try:
        from app.adapters.model_gateway import model_gateway

        msgs = [{
            "role": "user",
            "content": [
                {"type": "text", "text": "用一句话描述这张图里有什么。"},
                {"type": "image_url", "image_url": {"url": PUBLIC_IMG}},
            ],
        }]
        parts: list[str] = []
        async for delta in model_gateway.stream(msgs, agent_code="companion",
                                               trace_id="probe-companion"):
            parts.append(delta)
        text = "".join(parts).strip()
        print(f"      [companion] 累计 delta {len(parts)} 段，正文 {len(text)} 字", flush=True)
        if text:
            _rec(name, True, f"学伴链路读图成功：{text[:120]}")
        else:
            _rec(name, False, "学伴链路返回空正文（思考链吃光预算的典型指纹）")
    except Exception as exc:  # noqa: BLE001
        _rec(name, False, f"{type(exc).__name__}: {str(exc)[:300]}")


async def t_main_llm_variants() -> None:
    """主 LLM 直连三连：小预算 / 大预算 / 大预算+关思考，定位空正文根因"""
    cli = _client(settings.llm_base_url, settings.llm_api_key.get_secret_value())
    model = settings.llm_model

    try:
        t, d = await _raw_read(cli, model, PUBLIC_IMG, "llm-small-120", 120)
        _rec("T2a 复现：主 LLM max_tokens=120（未关思考）→ 预算被思考吃光",
             bool(t), f"已按预期复现空正文（{d}）—— 非通道缺陷，是预算问题",
             expectation=False)
    except Exception as exc:  # noqa: BLE001
        _rec("T2a 复现：主 LLM max_tokens=120（未关思考）→ 预算被思考吃光", False,
             f"{type(exc).__name__}: {str(exc)[:200]}", expectation=False)

    try:
        t, d = await _raw_read(cli, model, PUBLIC_IMG, "llm-big-4096", 4096)
        _rec("T2b 主 LLM · max_tokens=4096（未关思考）", bool(t), d)
    except Exception as exc:  # noqa: BLE001
        _rec("T2b 主 LLM · max_tokens=4096（未关思考）", False, f"{type(exc).__name__}: {str(exc)[:200]}")

    try:
        t, d = await _raw_read(cli, model, PUBLIC_IMG, "llm-nothink-512", 512, True)
        _rec("T2c 主 LLM · max_tokens=512 + 关思考", bool(t), d)
    except Exception as exc:  # noqa: BLE001
        _rec("T2c 主 LLM · max_tokens=512 + 关思考", False, f"{type(exc).__name__}: {str(exc)[:200]}")


# ---------------------------------------------------------------- 链路①③ VISION
async def t_vision_url() -> None:
    name = "T3 问诊/备课链路 · VISION 槽位读公网图 URL"
    if not settings.vision_configured:
        _rec(name, False, "vision 未配置")
        return
    try:
        cli = _client(settings.vision_base_url, settings.vision_api_key.get_secret_value())
        t, d = await _raw_read(cli, settings.vision_model, PUBLIC_IMG, "vision-url", 300)
        _rec(name, bool(t), f"VISION({settings.vision_model}) {d}")
    except Exception as exc:  # noqa: BLE001
        _rec(name, False, f"{type(exc).__name__}: {str(exc)[:300]}")


# ---------------------------------------------------------------- 链路④ 索引
async def t_vision_base64() -> None:
    name = "T4 图像索引链路 · VISION 槽位读 base64 内联图"
    if not settings.vision_configured:
        _rec(name, False, "vision 未配置")
        return
    try:
        uri = await _fetch_base64(PUBLIC_IMG)
        cli = _client(settings.vision_base_url, settings.vision_api_key.get_secret_value())
        t, d = await _raw_read(cli, settings.vision_model, uri, "vision-b64", 300)
        _rec(name, bool(t), f"base64 内联读图成功（与来源白名单无关） {d}")
    except Exception as exc:  # noqa: BLE001
        _rec(name, False, f"{type(exc).__name__}: {str(exc)[:300]}")


# ---------------------------------------------------------------- 校验门
def t_validate_matrix() -> None:
    from fastapi import HTTPException

    from app.api.vision import _validate_image_url

    prod_url = "http://8.160.161.158/zhiyu/case/x.png"
    saved_env, saved_hosts = settings.env, list(settings.vision_allowed_hosts)

    cases = [
        ("T5a 白名单写成 http://host（生产现状）· 放行",
         ["http://8.160.161.158"], prod_url, "pass"),
        ("T5b 白名单裸主机名 + HTTP 地址 · 拦截（未写协议默认仅 https）",
         ["8.160.161.158"], prod_url, "block"),
        ("T5c 白名单裸主机名 + HTTPS 地址 · 放行",
         ["8.160.161.158"], "https://8.160.161.158/x.png", "pass"),
        ("T5d 白名单带端口/路径/大写 · 归一化后放行",
         ["https://8.160.161.158:8443/a/b"], "https://8.160.161.158/x.png", "pass"),
        ("T5e 白名单外主机 · 继续拦截",
         ["http://8.160.161.158"], "http://evil.example.com/x.png", "block"),
        ("T5f 内网地址 · 继续拦截",
         ["http://8.160.161.158"], "http://192.168.1.10/x.png", "block"),
    ]
    try:
        settings.env = "prod"
        for title, hosts, url, expect in cases:
            settings.vision_allowed_hosts = hosts
            try:
                _validate_image_url(url)
                got, detail = "pass", "放行"
            except HTTPException as he:
                got, detail = "block", f"拦截 {he.status_code} {he.detail}"
            except Exception as exc:  # noqa: BLE001
                got, detail = "error", f"{type(exc).__name__}: {exc}"
            print(f"      hosts={hosts} url={url}\n"
                  f"        -> {detail} (期望 {expect} / 实际 {got})", flush=True)
            _rec(title, got == expect, detail)
    finally:
        settings.env = saved_env
        settings.vision_allowed_hosts = saved_hosts


async def main() -> int:
    print("=" * 78)
    print("配置快照")
    print(f"  env        = {settings.env}")
    print(f"  LLM        = {settings.llm_model} @ {settings.llm_base_url}")
    print(f"  VISION     = {settings.vision_model} @ {settings.vision_base_url}")
    print(f"  白名单     = {settings.vision_allowed_hosts}")
    print(f"  llm_max_tokens = {settings.llm_max_tokens}")
    print(f"  探针图片   = {PUBLIC_IMG}")
    print("=" * 78)

    await t_companion_real()
    await t_main_llm_variants()
    await t_vision_url()
    await t_vision_base64()
    t_validate_matrix()

    print("\n" + "=" * 78)
    print("汇总")
    for n, ok, _ in RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {n}")
    failed = [n for n, ok, _ in RESULTS if not ok]
    print(f"\n  通过 {len(RESULTS) - len(failed)}/{len(RESULTS)}")
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(asyncio.run(main()))
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        sys.exit(2)
