"""统一 Agent 网关的单元测试（阶段3）。

覆盖：6 分组 action 完整性、默认 action 推断、未知分组 404、未知 action 400、
请求体校验失败 422、管理端停用分组的网关级降级。
"""
import pytest
from fastapi import HTTPException, status
from pydantic import BaseModel

from app.agents.gateway_features import FEATURES, GROUPS, default_action_for
from app.api.agent_gateway import AgentGatewayRequest, agent_gateway
from app.services.config_center import config_center


def test_all_groups_mapped_to_features_and_valid():
    for group, spec in GROUPS.items():
        assert group in FEATURES, f"分组 {group} 未映射 FEATURES"
        assert FEATURES[group], f"分组 {group} 无 action"
        for action, feat in FEATURES[group].items():
            assert feat.group == group, f"{group}.{action} 分组不符"
            assert issubclass(feat.model, BaseModel), f"{group}.{action} 非 pydantic 模型"
            assert callable(feat.handler), f"{group}.{action} 缺 handler"


def test_seven_agent_groups_defined():
    assert set(GROUPS) == {"consultation", "mentor", "evaluator", "coach", "teacher", "lesson", "companion"}


def test_default_action_for_single_and_multi_action_groups():
    assert default_action_for("mentor") == "update_tree"
    assert default_action_for("consultation") is None
    assert default_action_for("companion") is None


async def test_unknown_group_returns_404():
    with pytest.raises(HTTPException) as exc:
        await agent_gateway("nope", AgentGatewayRequest(task={}), None)
    assert exc.value.status_code == status.HTTP_404_NOT_FOUND


async def test_unknown_action_returns_400():
    with pytest.raises(HTTPException) as exc:
        await agent_gateway("consultation", AgentGatewayRequest(action="nope", task={}), None)
    assert exc.value.status_code == status.HTTP_400_BAD_REQUEST


async def test_missing_action_on_multi_action_group_returns_400():
    with pytest.raises(HTTPException) as exc:
        await agent_gateway("teacher", AgentGatewayRequest(task={}), None)
    assert exc.value.status_code == status.HTTP_400_BAD_REQUEST


async def test_validation_failure_returns_422(monkeypatch):
    monkeypatch.setattr(config_center, "agents", {})
    # message 为空串触发 min_length=1 校验失败
    with pytest.raises(HTTPException) as exc:
        await agent_gateway(
            "companion",
            AgentGatewayRequest(action="sync", task={"message": ""}),
            None,
        )
    assert exc.value.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


async def test_disabled_group_degrades_at_gateway(monkeypatch):
    monkeypatch.setattr(
        config_center, "agents", {"consultation": {"enabled": False}}
    )
    resp = await agent_gateway(
        "consultation",
        AgentGatewayRequest(action="sync", task={}),
        None,
    )
    assert resp["data"]["status"] == "DEGRADED"
    assert resp["data"]["reason"] == "agent_disabled"