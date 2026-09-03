"""AI 配置中心 · 内网接口（管理端可视化运行态 / 基线导入）

仅允许业务中台（携带 X-Internal-Token）访问，作为「管理端 AI 配置中心」的观测面：

- /internal/config/baseline/prompts ：AI 中台内置提示词基线，供管理端一键导入数据库再编辑
- /internal/config/baseline/agents  ：AI 中台内置 Agent 元参数基线
- /internal/config/status           ：运行态快照（刷新时间/生效来源/RAG 生效值/模型脱敏视图）

说明：model_registry.latest 内含明文 apiKey，仅内部自用；此接口对外只返回脱敏后的
capability/model/baseUrl(host)，杜绝把密钥带出 AI 中台。
"""
from typing import Any
from urllib.parse import urlparse

from fastapi import APIRouter, Depends

from app.core.config import settings
from app.core.security import require_internal_token
from app.prompts.templates import baseline_prompts, baseline_agents, _PROMPT_DEFS, AGENT_DEFS
from app.services.config_center import config_center
from app.services.model_registry import model_registry

router = APIRouter(prefix="/internal/config", tags=["internal-config"])


@router.get("/baseline/prompts")
def get_baseline_prompts(_: None = Depends(require_internal_token)):
    return {"code": 0, "data": baseline_prompts()}


@router.get("/baseline/agents")
def get_baseline_agents(_: None = Depends(require_internal_token)):
    return {"code": 0, "data": baseline_agents()}


def _sanitize_model(cap: str, cfg: dict[str, Any]) -> dict[str, Any]:
    """脱敏模型视图：去掉 apiKey，仅保留排查所需的定位信息"""
    base = str(cfg.get("baseUrl") or "")
    host = urlparse(base).netloc if base else ""
    out: dict[str, Any] = {
        "capability": cap,
        "model": cfg.get("model") or "",
        "baseUrl": base,
        "host": host,
        "configured": bool(cfg.get("baseUrl")) and bool(cfg.get("model")),
    }
    if cfg.get("temperature") is not None:
        out["temperature"] = cfg["temperature"]
    if cfg.get("maxTokens"):
        out["maxTokens"] = cfg["maxTokens"]
    return out


@router.get("/status")
def get_config_status(_: None = Depends(require_internal_token)):
    """运行态快照：配置同步状态 / 模型注册表 / 生效来源 / RAG 生效值 / 模型脱敏视图。"""
    summary = config_center.status_summary()
    model_summary = model_registry.status_summary()

    # 生效来源：对已知内置键（含运行中回退的）逐一标注 DB 生效与否
    prompt_sources = {
        name: {"source": config_center.get_effective_prompt_source(name),
               "title": _PROMPT_DEFS[name]["title"]}
        for name in _PROMPT_DEFS
    }
    agent_sources = {
        code: {"source": config_center.get_effective_agent_source(code),
               "name": AGENT_DEFS[code]["name"]}
        for code in AGENT_DEFS
    }

    # 脱敏模型视图
    models = {
        cap: _sanitize_model(cap, cfg)
        for cap, cfg in model_registry.latest.items()
    }

    return {
        "code": 0,
        "data": {
            "app": {
                "name": settings.app_name,
                "version": settings.app_version,
                "env": settings.env,
                "llm_configured": bool(settings.llm_configured),
            },
            "refresh": summary,
            "modelRegistry": model_summary,
            "refreshIntervalSeconds": model_summary["refresh_interval_seconds"],
            "effective": {
                "promptSource": prompt_sources,
                "agentSource": agent_sources,
                "runtime": summary["runtime_effective"],
            },
            "models": models,
        },
    }


@router.post("/refresh")
async def refresh_config(_: None = Depends(require_internal_token)):
    """管理员显式触发一次全量配置刷新，并返回可核验的刷新结果。

    同时刷新模型注册表（模型连接参数）与配置中心（提示词/Agent/RAG 运行参数），
    保证「立即应用配置」对全部三类配置即时生效，而非等待周期轮询。
    任一类失败均不抛错：保留上一份有效快照，通过 last_error/ok 明确暴露。
    """
    await model_registry.refresh()
    await config_center.refresh()
    model_status = model_registry.status_summary()
    return {
        "code": 0,
        "data": {
            "ok": model_status["last_error"] is None,
            "modelRegistry": model_status,
            "configCenter": config_center.status_summary(),
        },
    }
