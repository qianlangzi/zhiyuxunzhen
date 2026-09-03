import pytest


@pytest.mark.asyncio
async def test_status_requires_ops_token(client):
    response = await client.get("/status")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_task_submission_requires_internal_token(client):
    response = await client.post(
        "/v1/ai/tasks",
        json={"taskType": "review", "idempotencyKey": "review:1", "payload": {}},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_async_review_requires_internal_token(client):
    response = await client.post(
        "/review/medical_record/async",
        json={"instanceId": 1, "medicalRecordText": "record"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_knowledge_ingest_requires_internal_token(client):
    response = await client.post(
        "/knowledge/ingest",
        json={"textbookId": 1, "objectKey": "textbooks/book.pdf"},
    )
    assert response.status_code == 401
