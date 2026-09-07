"""Contract tests for all AI platform API endpoints.

These tests verify the request/response shapes of every endpoint.
They serve as a regression baseline BEFORE any refactoring changes.
All external dependencies are mocked — no real LLM/Milvus/Redis/Spring Boot calls.

Endpoints covered:
    POST /v1/ai/chat/stream          — SSE multi-modal consultation (JWT auth)
    POST /review/medical_record      — Medical record review (X-Internal-Token)
    POST /daily_case/evaluate        — Daily case evaluation (X-Internal-Token)
    POST /learning_path/generate     — Learning path generation (X-Internal-Token)
    POST /report/generate_review_pdf — Review report generation (X-Internal-Token)
    POST /embed/textbook             — Textbook embedding (X-Internal-Token)
    POST /v1/ai/vision/analyze       — Vision analysis (student JWT + session ownership)
    GET  /health                     — Health check
"""
import json

import pytest
from pydantic import SecretStr

from app.core.config import settings


# ---------------------------------------------------------------------------
# SSE parsing helper
# ---------------------------------------------------------------------------
def parse_sse_events(text: str) -> list[dict]:
    """Parse raw SSE response text into a list of ``{event, data}`` dicts.

    Handles both ``\\r\\n`` and ``\\n`` line endings. Each SSE event block
    is separated by a blank line.
    """
    events: list[dict] = []
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    for block in normalized.split("\n\n"):
        if not block.strip():
            continue
        event_type: str | None = None
        event_data: str | None = None
        for line in block.split("\n"):
            if line.startswith("event:"):
                event_type = line[len("event:"):].strip()
            elif line.startswith("data:"):
                event_data = line[len("data:"):].strip()
        if event_type is not None:
            events.append({"event": event_type, "data": event_data})
    return events


# ---------------------------------------------------------------------------
# POST /v1/ai/chat/stream  (SSE, JWT auth)
# ---------------------------------------------------------------------------
class TestChatStream:
    """SSE consultation endpoint — verifies event structure and data validity."""

    async def test_chat_stream_emits_done_with_session_id(
        self, client, student_jwt_token
    ):
        """The ``done`` event must always be present and contain ``session_id``."""
        headers = {"Authorization": student_jwt_token}
        body = {
            "case_id": 1,
            "session_id": 1,
            "messages": [{"role": "student", "content": "医生，我最近头痛"}],
        }
        resp = await client.post("/v1/ai/chat/stream", json=body, headers=headers)
        assert resp.status_code == 200

        events = parse_sse_events(resp.text)
        event_types = [e["event"] for e in events]

        # done is mandatory
        assert "done" in event_types

        done_event = next(e for e in events if e["event"] == "done")
        done_data = json.loads(done_event["data"])
        assert "session_id" in done_data
        assert done_data["session_id"] == 1

    async def test_chat_stream_emits_message_events_with_delta(
        self, client, student_jwt_token
    ):
        """``message`` events must exist and each ``data`` must contain ``delta``."""
        headers = {"Authorization": student_jwt_token}
        body = {
            "case_id": 1,
            "session_id": 1,
            "messages": [{"role": "student", "content": "医生，我最近头痛"}],
        }
        resp = await client.post("/v1/ai/chat/stream", json=body, headers=headers)
        assert resp.status_code == 200

        events = parse_sse_events(resp.text)
        message_events = [e for e in events if e["event"] == "message"]
        assert len(message_events) > 0

        for msg in message_events:
            data = json.loads(msg["data"])
            assert "delta" in data
            assert isinstance(data["delta"], str)

    async def test_chat_stream_emits_tree_event(self, client, student_jwt_token):
        """训练态默认不回传 实时``tree``事件（防剧透诊断，见 consultation_graph.mentor_update）。

        依据：``settings.live_mentor_hint_enabled=False`` 时思维树/苏格拉底提示不实时进入
        问诊流（复盘思维树由结束时 evaluator 一并产出），故应答事件里不应包含 ``tree``。
        """
        headers = {"Authorization": student_jwt_token}
        body = {
            "case_id": 1,
            "session_id": 1,
            "messages": [{"role": "student", "content": "医生，我最近头痛"}],
        }
        resp = await client.post("/v1/ai/chat/stream", json=body, headers=headers)
        assert resp.status_code == 200

        events = parse_sse_events(resp.text)
        tree_events = [e for e in events if e["event"] == "tree"]
        # 默认训练态实时对话不应下发思维树事件（避免剧透采集点）
        assert len(tree_events) == 0

    async def test_chat_stream_all_event_data_is_valid_json(
        self, client, student_jwt_token
    ):
        """Every event's ``data`` field must be parseable JSON."""
        headers = {"Authorization": student_jwt_token}
        body = {
            "case_id": 1,
            "session_id": 1,
            "messages": [{"role": "student", "content": "医生，我最近头痛"}],
        }
        resp = await client.post("/v1/ai/chat/stream", json=body, headers=headers)
        assert resp.status_code == 200

        events = parse_sse_events(resp.text)
        assert len(events) > 0

        for event in events:
            if event["data"]:
                json.loads(event["data"])  # must not raise

    async def test_chat_stream_rejects_missing_auth(self, client):
        """Without Authorization header, endpoint should return 401."""
        body = {
            "case_id": 1,
            "session_id": 1,
            "messages": [{"role": "student", "content": "hello"}],
        }
        resp = await client.post("/v1/ai/chat/stream", json=body)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /review/medical_record  (X-Internal-Token)
# ---------------------------------------------------------------------------
class TestReviewMedicalRecord:
    """Medical record review — verifies R{code, message, data} structure."""

    async def test_review_returns_r_structure(self, client, internal_token_header):
        body = {
            "instanceId": 1,
            "medicalRecordText": "患者主诉头痛3天，伴恶心呕吐...",
        }
        resp = await client.post(
            "/review/medical_record", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        data = resp.json()
        assert "code" in data
        assert "message" in data
        assert "data" in data
        assert data["code"] == 0

    async def test_review_data_contains_required_fields(
        self, client, internal_token_header
    ):
        body = {
            "instanceId": 1,
            "medicalRecordText": "患者主诉头痛3天，伴恶心呕吐...",
        }
        resp = await client.post(
            "/review/medical_record", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        review_data = resp.json()["data"]
        assert "instanceId" in review_data
        assert "totalScore" in review_data
        assert "mistakes" in review_data
        assert "reviewComment" in review_data
        assert isinstance(review_data["mistakes"], list)

    async def test_review_rejects_missing_token(self, client):
        body = {"instanceId": 1, "medicalRecordText": "test"}
        resp = await client.post("/review/medical_record", json=body)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /daily_case/evaluate  (X-Internal-Token)
# ---------------------------------------------------------------------------
class TestDailyCaseEvaluate:
    """Daily case evaluation — verifies R structure and rule-based judging."""

    async def test_daily_case_rule_based_correct(self, client, internal_token_header):
        """With standardAnswer present, rule-based judging should work without LLM."""
        body = {
            "studentId": 1,
            "caseId": 1,
            "answer": "上呼吸道感染",
            "standardAnswer": "上呼吸道感染",
        }
        resp = await client.post(
            "/daily_case/evaluate", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        data = resp.json()
        assert data["code"] == 0
        assert "data" in data

        eval_data = data["data"]
        assert "studentId" in eval_data
        assert "caseId" in eval_data
        assert "correct" in eval_data
        assert "correctAnswer" in eval_data
        assert "explanation" in eval_data
        assert eval_data["correct"] is True
        assert eval_data["correctAnswer"] == "上呼吸道感染"

    async def test_daily_case_rule_based_incorrect(self, client, internal_token_header, monkeypatch):
        """开放作答经 LLM 评审判错（显式 mock 判错结果，兼容 LLM 评审语义）。"""
        from app.services.llm_client import llm_client

        async def mark_wrong(*args, **kwargs) -> dict:
            return {
                "correct": False,
                "correctAnswer": "上呼吸道感染",
                "explanation": "症状更符合上呼吸道感染，而非肺炎。",
                "textbookRef": "《内科学》感染篇",
            }

        monkeypatch.setattr(llm_client, "chat_json", mark_wrong)

        body = {
            "studentId": 1,
            "caseId": 1,
            "answer": "肺炎",
            "standardAnswer": "上呼吸道感染",
        }
        resp = await client.post(
            "/daily_case/evaluate", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        eval_data = resp.json()["data"]
        assert eval_data["correct"] is False

    async def test_daily_case_rejects_missing_token(self, client):
        body = {"studentId": 1, "caseId": 1, "answer": "test"}
        resp = await client.post("/daily_case/evaluate", json=body)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /learning_path/generate  (X-Internal-Token)
# ---------------------------------------------------------------------------
class TestLearningPathGenerate:
    """Learning path generation — verifies R structure and data fields."""

    async def test_learning_path_returns_r_structure(
        self, client, internal_token_header
    ):
        body = {"studentId": 1}
        resp = await client.post(
            "/learning_path/generate", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        data = resp.json()
        assert "code" in data
        assert "message" in data
        assert "data" in data
        assert data["code"] == 0

    async def test_learning_path_data_contains_required_fields(
        self, client, internal_token_header
    ):
        body = {"studentId": 1}
        resp = await client.post(
            "/learning_path/generate", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        path_data = resp.json()["data"]
        assert "studentId" in path_data
        assert "weakKnowledgeTags" in path_data
        assert "recommendedSteps" in path_data
        assert "recommendedCases" in path_data
        assert "citations" in path_data
        assert isinstance(path_data["recommendedSteps"], list)
        assert isinstance(path_data["citations"], list)

    async def test_learning_path_rejects_missing_token(self, client):
        body = {"studentId": 1}
        resp = await client.post("/learning_path/generate", json=body)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /report/generate_review_pdf  (X-Internal-Token) — 能力已移除
# ---------------------------------------------------------------------------
@pytest.mark.skip(reason="报告能力已改为移动端确定性渲染（SSE report 事件），generate_review_pdf 路由不再存在")
class TestReportGenerate:
    """Review report generation — verifies R structure and report fields."""

    async def test_report_returns_r_structure(self, client, internal_token_header):
        body = {"sessionId": 1}
        resp = await client.post(
            "/report/generate_review_pdf", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        data = resp.json()
        assert "code" in data
        assert "message" in data
        assert "data" in data
        assert data["code"] == 0

    async def test_report_data_contains_required_fields(
        self, client, internal_token_header
    ):
        body = {"sessionId": 1}
        resp = await client.post(
            "/report/generate_review_pdf", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        report_data = resp.json()["data"]
        assert "sessionId" in report_data
        assert "title" in report_data
        assert "overview" in report_data
        assert "typicalMistakes" in report_data
        assert "standardPath" in report_data
        assert "textbookRefs" in report_data
        assert "nextSteps" in report_data

    async def test_report_rejects_missing_token(self, client):
        body = {"sessionId": 1}
        resp = await client.post("/report/generate_review_pdf", json=body)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /embed/textbook  (X-Internal-Token)
# ---------------------------------------------------------------------------
class TestEmbedTextbook:
    """Textbook embedding — verifies R structure and embed result fields."""

    async def test_embed_returns_r_structure(
        self, client, mock_pdf_service, internal_token_header
    ):
        body = {"textbookId": 1, "fileUrl": "http://example.com/test.pdf"}
        resp = await client.post(
            "/embed/textbook", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        data = resp.json()
        assert "code" in data
        assert "message" in data
        assert "data" in data
        assert data["code"] == 0

    async def test_embed_data_contains_required_fields(
        self, client, mock_pdf_service, internal_token_header
    ):
        body = {"textbookId": 1, "fileUrl": "http://example.com/test.pdf"}
        resp = await client.post(
            "/embed/textbook", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200

        embed_data = resp.json()["data"]
        assert "textbookId" in embed_data
        assert "chunkCount" in embed_data
        assert "vectorCount" in embed_data
        assert "status" in embed_data
        assert embed_data["chunkCount"] > 0
        assert embed_data["vectorCount"] > 0

    async def test_embed_rejects_missing_token(self, client):
        body = {"textbookId": 1, "fileUrl": "http://example.com/test.pdf"}
        resp = await client.post("/embed/textbook", json=body)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /v1/ai/vision/analyze  (student JWT + session ownership)
# ---------------------------------------------------------------------------
class TestVisionAnalyze:
    """Vision analysis requires the same student/session boundary as chat."""

    async def test_vision_returns_result_structure(self, client, student_jwt_token):
        body = {
            "session_id": 1,
            "image_url": "http://example.com/image.jpg",
        }
        resp = await client.post(
            "/v1/ai/vision/analyze", json=body,
            headers={"Authorization": student_jwt_token},
        )
        assert resp.status_code == 200

        data = resp.json()
        assert "finding" in data
        assert "citations" in data
        assert "safety_blocked" in data
        assert isinstance(data["citations"], list)
        assert isinstance(data["safety_blocked"], bool)

    async def test_vision_rejects_missing_auth(self, client):
        """A caller without a student JWT cannot spend the vision model budget."""
        body = {
            "session_id": 1,
            "image_url": "http://example.com/image.jpg",
        }
        resp = await client.post("/v1/ai/vision/analyze", json=body)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /internal/agent/{code}  (统一 Agent 网关, X-Internal-Token)
# ---------------------------------------------------------------------------
class TestAgentGateway:
    """统一 Agent 网关——6 分组收敛后的单入口，验证 R 结构与 SSE 契约。"""

    async def test_mentor_update_tree_returns_r(self, client, internal_token_header):
        body = {
            "action": "update_tree",
            "task": {"session_id": 1, "student_id": 1, "messages": []},
        }
        resp = await client.post(
            "/internal/agent/mentor", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["code"] == 0
        assert "nodes" in data["data"]
        assert "edges" in data["data"]

    async def test_evaluator_medical_record_returns_r(self, client, internal_token_header):
        body = {
            "action": "medical_record",
            "task": {"instanceId": 1, "medicalRecordText": "患者主诉头痛3天..."},
        }
        resp = await client.post(
            "/internal/agent/evaluator", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["code"] == 0
        assert "totalScore" in data["data"]
        assert isinstance(data["data"]["mistakes"], list)

    async def test_coach_learning_path_returns_r(self, client, internal_token_header):
        body = {"action": "learning_path", "task": {"studentId": 1}}
        resp = await client.post(
            "/internal/agent/coach", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["code"] == 0
        assert "pathSteps" in data["data"] or "recommendedSteps" in data["data"]

    async def test_teacher_recommend_cases_returns_r(self, client, internal_token_header):
        body = {
            "action": "recommend_cases",
            "task": {"classId": 1, "weaknesses": [], "candidateCases": []},
        }
        resp = await client.post(
            "/internal/agent/teacher", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["code"] == 0
        assert "recommendations" in data["data"]

    async def test_companion_stream_is_sse(self, client, internal_token_header):
        body = {"action": "stream", "task": {"message": "最近学得有点累", "studentId": 1}}
        resp = await client.post(
            "/internal/agent/companion", json=body, headers=internal_token_header
        )
        assert resp.status_code == 200
        assert resp.headers.get("content-type", "").startswith("text/event-stream")
        events = parse_sse_events(resp.text)
        types = {ev["event"] for ev in events}
        assert "done" in types

    async def test_unknown_group_returns_404(self, client, internal_token_header):
        resp = await client.post(
            "/internal/agent/nope", json={"task": {}}, headers=internal_token_header
        )
        assert resp.status_code == 404

    async def test_rejects_missing_token(self, client):
        resp = await client.post("/internal/agent/mentor", json={"task": {}})
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# GET /health
# ---------------------------------------------------------------------------
class TestHealth:
    """Health check — verifies 200 response with status field."""

    async def test_health_returns_200(self, client):
        resp = await client.get("/health")
        assert resp.status_code == 200

    async def test_health_contains_status_up(self, client):
        resp = await client.get("/health")
        data = resp.json()
        assert data["status"] == "UP"

    async def test_health_contains_app_info(self, client):
        resp = await client.get("/health")
        data = resp.json()
        assert "app" in data
        assert "version" in data
        assert "env" in data

    async def test_ready_reports_unconfigured_llm(self, client):
        """LLM 未配置（mock_settings 已显式置空 llm 配置）→ configured=false。

        该断言与开发者本机 .env 解耦：无论 .env 是否配置真实 LLM，
        mock_settings fixture 都会把 llm_base_url/llm_api_key 置空。
        """
        resp = await client.get("/ready")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "READY"
        assert data["checks"]["llm"]["configured"] is False

    async def test_ready_reports_configured_llm(self, client, monkeypatch):
        """LLM 已配置（显式覆盖为假配置）→ configured=true。

        仅使用占位假值覆盖 llm_base_url/llm_api_key，验证 configured=true 分支，
        不会读取或打印开发者本机 .env 中的真实密钥。
        """
        monkeypatch.setattr(
            settings, "llm_base_url", "https://llm.example.invalid/v1"
        )
        monkeypatch.setattr(
            settings, "llm_api_key", SecretStr("sk-fake-test-key-not-real")
        )
        resp = await client.get("/ready")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "READY"
        assert data["checks"]["llm"]["configured"] is True
