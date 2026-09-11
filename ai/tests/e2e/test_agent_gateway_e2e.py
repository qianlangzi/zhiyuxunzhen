"""端到端验证：7 个 Agent 分组经统一网关 ``/internal/agent/{code}`` 全链路真正可用。

与 contract 测试的区别：本套件沿真实 HTTP 路由（含鉴权/请求体校验/采样上下文注入），
逐一打通每个分组的一个代表 action，验证 200 + R 壳结构成立。
LLM / 后端 / RAG / Milvus 均 mock，不产生真实网络调用。
"""
import json

import pytest

from app.agents.gateway_features import GROUPS
from app.services.llm_client import llm_client

# group -> (action, 合法 task 载荷) —— 这些 action 的 AI 输出由共享 mock 满足，应回 code==0
_GREEN = {
    "consultation": ("sync", {"student_id": 1, "session_id": 1, "case_id": 1,
                              "messages": [{"role": "student", "content": "医生，我最近头痛"}]}),
    "mentor": ("update_tree", {"student_id": 1, "session_id": 1}),
    "evaluator": ("medical_record", {"instanceId": 1, "medicalRecordText": "患者发热伴咳嗽 3 天，查体……"}),
    "coach": ("learning_path", {"studentId": 1}),
    "companion": ("sync", {"message": "你好，我今天有点焦虑"}),
}


async def _post(client, headers, code, action, task):
    return await client.post(
        f"/internal/agent/{code}",
        json={"action": action, "task": task},
        headers=headers,
    )


async def test_e2e_every_green_group_returns_R_with_code_0(client, internal_token_header):
    for code, (action, task) in _GREEN.items():
        resp = await _post(client, internal_token_header, code, action, task)
        assert resp.status_code == 200, f"{code}/{action} -> HTTP {resp.status_code}: {resp.text[:200]}"
        body = resp.json()
        assert body.get("code") == 0, f"{code}/{action} 业务码异常: {body}"
        assert "data" in body, f"{code}/{action} 缺少 data 字段"


async def test_e2e_teacher_case_draft_code_0(client, internal_token_header, monkeypatch):
    """teacher/case_draft 读取 llm_client.chat 的 JSON 字符串，需形状精确的 mock（extra 拒收）。"""
    async def fake_chat(messages, *, model=None, temperature=None, max_tokens=None, trace_id="-"):
        return json.dumps({
            "patientProfile": "患者男性，35 岁，主诉胸痛 2 小时伴大汗",
            "hiddenDisease": "急性心肌梗死",
        }, ensure_ascii=False)
    monkeypatch.setattr(llm_client, "chat", fake_chat)
    resp = await _post(client, internal_token_header, "teacher", "case_draft",
                       {"chiefComplaint": "胸痛2小时", "department": "心血管内科"})
    assert resp.status_code == 200
    body = resp.json()
    assert body.get("code") == 0, f"teacher/case_draft 业务码异常: {body}"
    assert body["data"]["hiddenDisease"] == "急性心肌梗死"


async def test_e2e_lesson_design_code_0_and_its_own_sampling(client, internal_token_header, monkeypatch):
    """lesson/lesson_design：独立分组，应 200 且网关注入的采样上下文用 lesson 内置 spec（0.5, 3072）。"""
    from app.core.logging import get_agent_sampling

    captured: dict = {}

    async def fake_chat(messages, *, model=None, temperature=None, max_tokens=None, trace_id="-"):
        # 网关在调 handler 前 set_agent_sampling；真正 llm_client.chat 通过该
        # ContextVar 应用温度/长度。mock 绕过 apply 层，故改断言上下文本身。
        captured["ctx"] = get_agent_sampling()
        return json.dumps({
            "teachingObjectives": ["掌握急性心梗的鉴别诊断"],
            "keyPoints": ["胸痛病因分析"],
            "keyDifficultPoints": ["心梗早期识别"],
            "lessonOutline": [{"phase": "导入", "duration": 10, "content": "病例引入"}],
            "caseDiscussion": ["该病例提示什么诊断？"],
            "skillTraining": [{"name": "问诊", "description": "SP 问诊", "duration": 15}],
            "spInterviewDesign": ["主诉", "追问"],
            "boardDesign": "板书",
            "homeworkSuggestions": ["复习心电图"],
            "teachingReflection": "强调时间线",
            "textbookRefs": [],
        }, ensure_ascii=False)

    monkeypatch.setattr(llm_client, "chat", fake_chat)
    resp = await _post(client, internal_token_header, "lesson", "lesson_design",
                       {"title": "急性心肌梗死", "department": "心血管内科"})
    assert resp.status_code == 200, f"lesson/lesson_design -> {resp.status_code}: {resp.text[:300]}"
    body = resp.json()
    assert body.get("code") == 0, f"lesson/lesson_design 业务码异常: {body}"
    assert body["data"]["keyPoints"][0] == "胸痛病因分析"
    # 采样上下文必须用 lesson 内置默认（独立于 teacher），证明分组确实生效
    assert captured.get("ctx") == (0.5, 3072, None), f"lesson 采样上下文未生效: {captured}"


async def test_e2e_consultation_stream_is_sse(client, internal_token_header):
    resp = await _post(client, internal_token_header, "consultation", "stream",
                       {"student_id": 1, "session_id": 1, "case_id": 1,
                        "messages": [{"role": "student", "content": "医生，我最近头痛"}]})
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers.get("content-type", "")
    assert "done" in resp.text  # SSE 契约必需 done 事件


async def test_e2e_stream_propagates_agent_sampling(client, internal_token_header, monkeypatch):
    """回归：流式动作的「AI 配置中心」热配采样必须真正到达 llm.stream。

    曾经的隐形 bug：网关 try/finally 在 handler 返回 EventSourceResponse 后立即
    清除采样 ContextVar，而生成器体（真正调 llm.stream）在响应发送阶段才执行，
    导致流式热配静默失效、回退到全局默认。
    """
    from app.core.logging import get_agent_sampling

    captured: dict = {}

    async def fake_stream(messages, *, model=None, temperature=None, max_tokens=None,
                          disable_thinking=False, trace_id="-"):
        captured["ctx"] = get_agent_sampling()
        captured["temp"] = temperature
        for word in ["啊", "，", "你好"]:
            yield word

    monkeypatch.setattr(llm_client, "stream", fake_stream)
    resp = await _post(client, internal_token_header, "consultation", "stream",
                       {"student_id": 1, "session_id": 1, "case_id": 1,
                        "messages": [{"role": "student", "content": "你好"}]})
    await resp.aread()
    assert resp.status_code == 200
    # consultation 内置 spec：temperature=0.7, max_tokens=1024, model=None
    assert captured["ctx"] == (0.7, 1024, None), f"流式热配采样失效: ctx={captured.get('ctx')}"
    assert captured["temp"] == 0.7


async def test_e2e_invalid_task_returns_422(client, internal_token_header):
    resp = await _post(client, internal_token_header, "companion", "sync", {"message": ""})
    assert resp.status_code == 422


async def test_e2e_unknown_group_returns_404(client, internal_token_header):
    resp = await _post(client, internal_token_header, "nonexistent", "x", {})
    assert resp.status_code == 404


async def test_e2e_options_stream_mismatch_returns_400(client, internal_token_header):
    """同步动作若显式声明 options.stream=true，属上层运输方式误配，应被 400 拦截而非静默降级。"""
    resp = await client.post(
        "/internal/agent/companion",
        json={"action": "sync", "task": {"message": "你好"}, "options": {"stream": True}},
        headers=internal_token_header,
    )
    assert resp.status_code == 400


async def test_e2e_trace_id_propagates_to_llm(client, internal_token_header, monkeypatch):
    """全链路 trace：入站 X-Trace-Id 必须透传到 handler 内实际发起的 LLM 调用。

    回归保障：handler 不得再用 str(uuid.uuid4()) 覆盖中间件按入站头注入的 trace；
    否则跨系统日志无法按同一 trace 关联。
    """
    captured: dict = {}

    async def fake_stream(messages, *, model=None, temperature=None, max_tokens=None,
                          disable_thinking=False, trace_id="-"):
        captured["trace_id"] = trace_id
        for word in ["你好", "，", "我是", "模拟", "学伴", "。"]:
            yield word

    monkeypatch.setattr(llm_client, "stream", fake_stream)
    my_trace = "e2e-upstream-trace-abcdef123456"
    resp = await client.post(
        "/internal/agent/companion",
        json={"action": "sync", "task": {"message": "你好"}},
        headers={**internal_token_header, "X-Trace-Id": my_trace},
    )
    assert resp.status_code == 200
    # LLM 调用必须复用入站 trace（而非本地重新生成）
    assert captured.get("trace_id") == my_trace, f"trace 未透传: {captured}"
    # 响应头回传同一 trace，便于下游与本端日志对齐
    assert resp.headers.get("X-Trace-Id") == my_trace