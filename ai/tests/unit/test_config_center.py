"""ConfigCenter 的 Agent 定义解析单测（阶段 2）。

验证：_parse_tools_config 的三种形态；resolve_agent_spec 将业务中台热配字段
合并进内置 AgentSpec 默认；不可识别字段被忽略保持兼容。
"""
from app.services.config_center import (
    STRATEGY_CODE,
    STRATEGY_LOOP,
    STRATEGY_TOOL,
    AgentSpec,
    ConfigCenter,
    _parse_tools_config,
)


def _spec() -> AgentSpec:
    return AgentSpec(code="review", strategy=STRATEGY_CODE, tools=("search",))


def _center(agents: dict) -> ConfigCenter:
    cc = ConfigCenter()
    cc.agents = agents
    return cc


# ---------------- _parse_tools_config ----------------

def test_parse_tools_dict_keeps_enabled_only():
    assert _parse_tools_config({"search": True, "web": False, "calc": True}) == (
        "search",
        "calc",
    )


def test_parse_tools_list_all_enabled():
    assert _parse_tools_config(["search", "web", "calc"]) == (
        "search",
        "web",
        "calc",
    )
    assert _parse_tools_config([]) == ()


def test_parse_tools_invalid_returns_none():
    assert _parse_tools_config(12345) is None
    assert _parse_tools_config(None) is None


# ---------------- resolve_agent_spec ----------------

def test_resolve_keeps_defaults_when_no_hot_config():
    cc = _center({})
    spec = cc.resolve_agent_spec("review", _spec())
    assert spec == _spec()


def test_resolve_merges_hot_fields():
    cc = _center(
        {
            "review": {
                "name": "病历批阅v2",
                "strategy": "tool",
                "temperature": 0.2,
                "max_tokens": 2048,
                "maxIterations": 5,
                "stopCondition": "answer_found",
                "enabled": False,
                "toolsConfig": {"search": True, "web": False},
            }
        }
    )
    spec = cc.resolve_agent_spec("review", _spec())
    assert spec.name == "病历批阅v2"
    assert spec.strategy == STRATEGY_TOOL
    assert spec.temperature == 0.2
    assert spec.max_tokens == 2048
    assert spec.max_iterations == 5
    assert spec.stop_condition == "answer_found"
    assert spec.enabled is False
    assert spec.tools == ("search",)
    # 未配置字段取自默认
    assert spec.description == _spec().description


def test_resolve_strategy_and_tools_from_list_cfg():
    cc = _center(
        {
            "coach": {
                "strategy": "loop",
                "toolsConfig": ["search", "calc"],
            }
        }
    )
    spec = cc.resolve_agent_spec("coach", AgentSpec(code="coach"))
    assert spec.strategy == STRATEGY_LOOP
    assert spec.tools == ("search", "calc")


def test_resolve_ignores_unknown_fields():
    cc = _center({"review": {"weirdField": True, "strategy": "CODE"}})
    spec = cc.resolve_agent_spec("review", _spec())
    assert spec.strategy == STRATEGY_CODE
    assert spec.temperature is None