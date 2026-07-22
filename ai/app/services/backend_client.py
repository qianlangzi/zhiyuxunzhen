"""业务中台回调客户端（PRD 9.4）

封装 5 个回调接口，所有回调失败静默（不阻塞 AI 主流程），仅记录日志。
优先复用 lifecycle 中创建的共享 httpx.AsyncClient，避免每次请求临时创建连接池。
"""
import json
from typing import Any

import httpx

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING

logger = get_logger(__name__)


class BackendClient:
    """异步回调业务中台 /api/internal/* 接口"""

    def __init__(self) -> None:
        self._base_url = settings.backend_callback_url.rstrip("/")
        self._timeout = httpx.Timeout(10.0, connect=5.0)
        self._headers = {"X-Internal-Token": settings.internal_token.get_secret_value()}
        # 共享 HTTP client，由 lifecycle 注入；为 None 时临时创建
        self._shared_client: httpx.AsyncClient | None = None

    def set_shared_client(self, client: httpx.AsyncClient | None) -> None:
        """注入共享 HTTP client（由 lifecycle 在启动时调用）"""
        self._shared_client = client

    def _client(self) -> httpx.AsyncClient:
        """获取 HTTP client：优先复用共享实例，否则临时创建"""
        if self._shared_client is not None:
            return self._shared_client
        return httpx.AsyncClient(timeout=self._timeout, headers=self._headers)

    async def _close_if_temporary(self, client: httpx.AsyncClient) -> None:
        """临时 client 用完后关闭；共享 client 不关闭"""
        if self._shared_client is None:
            await client.aclose()

    async def _post(self, path: str, body: dict[str, Any], trace_id: str = "-") -> bool:
        url = f"{self._base_url}{path}"
        client = self._client()
        try:
            resp = await client.post(url, json=body, headers=self._headers)
            ok = 200 <= resp.status_code < 300
            log_event(
                logger,
                INFO if ok else WARNING,
                "backend_callback",
                trace_id=trace_id, path=path, status=resp.status_code,
            )
            return ok
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "backend_callback_error",
                      trace_id=trace_id, path=path, error=type(e).__name__, msg=str(e))
            return False
        finally:
            await self._close_if_temporary(client)

    async def session_context(
        self,
        session_id: int,
        student_id: int,
        trace_id: str = "-",
    ) -> dict[str, Any] | None:
        path = f"/api/internal/session/{session_id}/context"
        url = f"{self._base_url}{path}"
        client = self._client()
        try:
            response = await client.get(url, params={"studentId": student_id}, headers=self._headers)
            body = response.json()
            if response.status_code == 200 and body.get("code") == 0:
                return body.get("data")
            log_event(logger, WARNING, "session_context_rejected",
                      trace_id=trace_id, status=response.status_code,
                      code=body.get("code"))
            return None
        except Exception as exc:  # noqa: BLE001
            log_event(logger, WARNING, "session_context_error",
                      trace_id=trace_id, error=type(exc).__name__, msg=str(exc))
            return None
        finally:
            await self._close_if_temporary(client)

    async def report_context(self, session_id: int, trace_id: str = "-") -> dict[str, Any] | None:
        path = f"/api/internal/session/{session_id}/report-context"
        url = f"{self._base_url}{path}"
        client = self._client()
        try:
            response = await client.get(url, headers=self._headers)
            body = response.json()
            if response.status_code == 200 and body.get("code") == 0:
                return body.get("data")
            log_event(logger, WARNING, "report_context_rejected", trace_id=trace_id, status=response.status_code)
            return None
        except Exception as exc:  # noqa: BLE001
            log_event(logger, WARNING, "report_context_error", trace_id=trace_id, error=type(exc).__name__)
            return None
        finally:
            await self._close_if_temporary(client)

    async def append_session_messages(
        self,
        session_id: int,
        student_id: int,
        messages: list[dict[str, Any]],
        trace_id: str = "-",
    ) -> bool:
        return await self._post(
            f"/api/internal/session/{session_id}/messages",
            {"studentId": student_id, "messages": messages},
            trace_id,
        )

    # ---------- 1. 归档问诊会话 ----------
    async def archive_session(
        self,
        session_id: int,
        osce_score: dict[str, Any],
        final_report: str,
        reasoning_tree: dict[str, Any],
        trace_id: str = "-",
    ) -> bool:
        return await self._post(
            "/api/internal/session/archive",
            {
                "sessionId": session_id,
                "osceScoreJson": json.dumps(osce_score, ensure_ascii=False),
                "finalReport": final_report,
                "reasoningTreeJson": json.dumps(reasoning_tree, ensure_ascii=False),
            },
            trace_id,
        )

    # ---------- 2. AI 批阅结果回调 ----------
    async def review_callback(
        self,
        instance_id: int,
        total_score: float,
        mistakes: list[dict[str, Any]],
        review_comment: str,
        trace_id: str = "-",
    ) -> bool:
        return await self._post(
            "/api/internal/review/callback",
            {
                "instanceId": instance_id,
                "totalScore": total_score,
                "mistakesJson": json.dumps(mistakes, ensure_ascii=False),
                "reviewComment": review_comment,
            },
            trace_id,
        )

    # ---------- 3. 同步错题本 ----------
    async def sync_mistakes(
        self,
        mistakes: list[dict[str, Any]],
        trace_id: str = "-",
    ) -> bool:
        return await self._post(
            "/api/internal/mistakes/sync",
            {"mistakes": mistakes},
            trace_id,
        )

    # ---------- 4. 同步薄弱知识点 ----------
    async def sync_weakness(
        self,
        weakness_list: list[dict[str, Any]],
        trace_id: str = "-",
    ) -> bool:
        return await self._post(
            "/api/internal/weakness/sync",
            {"weaknessList": weakness_list},
            trace_id,
        )

    # ---------- 5. 模型异常/降级事件 ----------
    async def log_model_event(
        self,
        event_type: str,
        model_name: str,
        error_message: str,
        detail: dict[str, Any] | None = None,
        trace_id: str = "-",
    ) -> bool:
        return await self._post(
            "/api/internal/model-event/log",
            {
                "eventType": event_type,
                "modelName": model_name,
                "errorMessage": error_message,
                "detailJson": json.dumps(detail or {}, ensure_ascii=False),
            },
            trace_id,
        )


# 模块级单例
backend_client = BackendClient()
