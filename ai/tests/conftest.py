"""Test fixtures for AI platform contract tests.

Mocks all external dependencies (LLM, Milvus, Spring Boot, RAG) so tests
run entirely in-process without network calls.

Architecture notes:
- The codebase uses module-level singletons (e.g. ``backend_client``,
  ``llm_client``). We patch their methods via ``monkeypatch.setattr``
  so that every module that imported the singleton sees the mock.
- ``settings`` is also a singleton; we patch its attributes directly
  so that ``security.py`` (which reads ``jwt_secret`` / ``internal_token``
  at request time) uses our test values.
"""
import json
import time

import httpx
import jwt as pyjwt
import pytest
from pydantic import SecretStr

from app.core.config import settings
from app.main import app


@pytest.fixture(autouse=True)
def reset_sse_app_status():
    """Keep sse-starlette's process-global exit event scoped to each test loop."""
    from sse_starlette.sse import AppStatus

    AppStatus.should_exit = False
    AppStatus.should_exit_event = None
    yield
    AppStatus.should_exit = False
    AppStatus.should_exit_event = None

# ---------------------------------------------------------------------------
# Settings mock
# ---------------------------------------------------------------------------
@pytest.fixture
def mock_settings(monkeypatch):
    """Override settings with test-safe values.

    The real ``settings`` singleton is constructed at import time from
    environment variables. We mutate the *same object* so that every
    module holding a reference (security.py, api modules, etc.) sees
    the test values.
    """
    monkeypatch.setattr(settings, "env", "test")
    monkeypatch.setattr(
        settings,
        "jwt_secret",
        SecretStr("test-secret-key-32chars-minimum-aaaa"),
    )
    monkeypatch.setattr(
        settings,
        "internal_token",
        SecretStr("test-internal-token"),
    )


# ---------------------------------------------------------------------------
# JWT / internal-token fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
def student_jwt_token(mock_settings) -> str:
    """Create a valid JWT for a student user (role=0, type=access)."""
    payload = {
        # Spring Boot JwtUtils writes subject as String.valueOf(userId).
        "sub": "1",
        "type": "access",
        "role": 0,
        "exp": int(time.time()) + 3600,
    }
    token = pyjwt.encode(
        payload,
        "test-secret-key-32chars-minimum-aaaa",
        algorithm="HS256",
    )
    return f"Bearer {token}"


@pytest.fixture
def internal_token_header(mock_settings) -> dict[str, str]:
    """Return headers dict with X-Internal-Token for Spring-Boot callers."""
    return {"X-Internal-Token": "test-internal-token"}


# ---------------------------------------------------------------------------
# External dependency mocks
# ---------------------------------------------------------------------------
@pytest.fixture
def mock_backend_client(monkeypatch):
    """Mock ``backend_client`` singleton — all async methods return canned data."""
    from app.services.backend_client import backend_client

    async def fake_session_context(session_id, student_id, trace_id="-"):
        return {
            "caseId": 1,
            "messages": [],
            "title": "测试病例：发热待查",
            "patientProfile": {"name": "张三", "age": 30, "gender": "男"},
            "hiddenDisease": "上呼吸道感染",
            "standardPathJson": "{}",
            "presetExams": [],
        }

    async def fake_append_session_messages(
        session_id, student_id, messages, trace_id="-"
    ):
        return True

    async def fake_report_context(session_id, trace_id="-"):
        return {
            "sessionId": session_id,
            "caseTitle": "测试病例",
            "status": 1,
            "osceScoreJson": '{"history":20}',
            "messages": [],
        }

    async def fake_review_callback(
        instance_id, total_score, mistakes, review_comment, trace_id="-"
    ):
        return True

    async def fake_archive_session(
        session_id, osce_score, final_report, reasoning_tree, trace_id="-"
    ):
        return True

    async def fake_sync_mistakes(mistakes, trace_id="-"):
        return True

    async def fake_sync_weakness(weakness_list, trace_id="-"):
        return True

    async def fake_log_model_event(
        event_type, model_name, error_message, detail=None, trace_id="-"
    ):
        return True

    monkeypatch.setattr(backend_client, "session_context", fake_session_context)
    monkeypatch.setattr(
        backend_client, "append_session_messages", fake_append_session_messages
    )
    monkeypatch.setattr(backend_client, "report_context", fake_report_context)
    monkeypatch.setattr(backend_client, "review_callback", fake_review_callback)
    monkeypatch.setattr(backend_client, "archive_session", fake_archive_session)
    monkeypatch.setattr(backend_client, "sync_mistakes", fake_sync_mistakes)
    monkeypatch.setattr(backend_client, "sync_weakness", fake_sync_weakness)
    monkeypatch.setattr(backend_client, "log_model_event", fake_log_model_event)


@pytest.fixture
def mock_llm_client(monkeypatch):
    """Mock ``llm_client`` singleton — ``stream`` yields canned deltas,
    ``chat_json`` returns a universal dict satisfying all agent schemas.
    """
    from app.services.llm_client import llm_client

    async def fake_chat(
        messages, *, model=None, temperature=None, max_tokens=None, trace_id="-"
    ):
        return json.dumps({"totalScore": 85.0}, ensure_ascii=False)

    async def fake_stream(
        messages, *, model=None, temperature=None, max_tokens=None, trace_id="-"
    ):
        for word in ["你好", "，", "我是", "模拟", "病人", "。"]:
            yield word

    async def fake_chat_json(messages, *, model=None, trace_id="-"):
        # Universal dict — each endpoint reads only the keys it needs.
        return {
            # reviewer_agent
            "totalScore": 85.0,
            "mistakes": [
                {
                    "location": "主诉",
                    "type": "medical_fact",
                    "severity": "medium",
                    "comment": "诊断依据不充分",
                    "deduction": 5.0,
                }
            ],
            "reviewComment": "总体表现良好，但诊断依据需加强。",
            # daily_case (LLM path, not used when standardAnswer provided)
            "correct": True,
            "correctAnswer": "上呼吸道感染",
            "explanation": "症状符合上呼吸道感染诊断。",
            "textbookRef": "《内科学》第3章",
            # learning_path
            "weakKnowledgeTags": ["心电图判读", "鉴别诊断"],
            "recommendedSteps": ["复习《诊断学》心电图章节", "完成1个心血管病例"],
            "recommendedCases": [1, 2],
            # mentor_agent
            "nodes": [
                {"id": "n1", "type": "symptom", "label": "发热", "status": "queried"}
            ],
            "edges": [{"from": "n1", "to": "n2", "relation": "leads_to"}],
            "socrates_hint": "你是否考虑过其他鉴别诊断？",
            # report
            "title": "问诊训练复盘报告",
            "overview": "本次训练涵盖了主诉和现病史采集。",
            "typicalMistakes": ["未询问过敏史"],
            "standardPath": ["主诉", "现病史", "既往史", "查体", "诊断"],
            "textbookRefs": ["《诊断学》第1章"],
            "nextSteps": ["加强病史采集练习"],
        }

    async def fake_report_model_event(event_type, model_name, error_msg):
        pass

    monkeypatch.setattr(llm_client, "chat", fake_chat)
    monkeypatch.setattr(llm_client, "stream", fake_stream)
    monkeypatch.setattr(llm_client, "chat_json", fake_chat_json)
    monkeypatch.setattr(llm_client, "_report_model_event", fake_report_model_event)


@pytest.fixture
def mock_rag_service(monkeypatch):
    """Mock ``rag_service`` singleton — search returns empty, embed returns zero vectors."""
    from app.services.rag_service import rag_service

    async def fake_search(query, top_k=5, trace_id="-"):
        return []

    async def fake_embed(text, trace_id="-"):
        return [0.0] * settings.milvus_vector_dim

    async def fake_embed_batch(texts, trace_id="-"):
        return [[0.0] * settings.milvus_vector_dim for _ in texts]

    monkeypatch.setattr(rag_service, "search", fake_search)
    monkeypatch.setattr(rag_service, "embed", fake_embed)
    monkeypatch.setattr(rag_service, "embed_batch", fake_embed_batch)


@pytest.fixture
def mock_milvus_service(monkeypatch):
    """Mock ``milvus_service`` singleton — upsert returns count, search/count return empty."""
    from app.services.milvus_service import milvus_service

    async def fake_upsert(records, trace_id="-"):
        return len(records)

    async def fake_search(query_vec, top_k=5, trace_id="-"):
        return []

    async def fake_count(trace_id="-"):
        return 0

    monkeypatch.setattr(milvus_service, "upsert", fake_upsert)
    monkeypatch.setattr(milvus_service, "search", fake_search)
    monkeypatch.setattr(milvus_service, "count", fake_count)


@pytest.fixture
def mock_pdf_service(monkeypatch):
    """Mock ``fetch_pdf`` / ``parse_pdf`` in the embed module namespace.

    ``embed.py`` imports these as local names via ``from ... import``,
    so we must patch them on the ``app.api.embed`` module, not on
    ``pdf_service``.
    """
    from app.api import embed
    from app.services.pdf_service import TextChunk

    def fake_fetch_pdf(file_url, trace_id="-"):
        return b"fake pdf content"

    def fake_parse_pdf(content, trace_id="-"):
        return [
            TextChunk(text="第一章 概论", page_number=1, chapter="第一章"),
            TextChunk(text="第二章 诊断方法", page_number=5, chapter="第二章"),
        ]

    monkeypatch.setattr(embed, "fetch_pdf", fake_fetch_pdf)
    monkeypatch.setattr(embed, "parse_pdf", fake_parse_pdf)


# ---------------------------------------------------------------------------
# Async HTTP client (all common mocks applied)
# ---------------------------------------------------------------------------
@pytest.fixture
async def client(
    mock_settings,
    mock_backend_client,
    mock_llm_client,
    mock_rag_service,
    mock_milvus_service,
):
    """httpx AsyncClient backed by ASGITransport.

    All external dependencies are mocked so no real network calls occur.
    Endpoint-specific mocks (e.g. ``mock_pdf_service``) can be requested
    by individual tests in addition to this fixture.
    """
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield client
