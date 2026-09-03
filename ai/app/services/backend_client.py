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

    async def case_context(
        self,
        case_id: int,
        trace_id: str = "-",
    ) -> dict[str, Any] | None:
        """SP 开场白专用：直接按病例取上下文，不依赖会话是否存在。

        会话刚创建时 Spring Boot 外层事务可能尚未提交，按 session_id 回查
        ``/session/{id}/context`` 会拿到 1404（会话不存在），导致开场白拿不到
        病例上下文而自由发挥。开场只关心病例内容，用 case_id 直取即可彻底避开
        事务竞态（2026-09-02 修复）。
        """
        path = f"/api/internal/case/{case_id}/context"
        url = f"{self._base_url}{path}"
        client = self._client()
        try:
            response = await client.get(url, headers=self._headers)
            body = response.json()
            if response.status_code == 200 and body.get("code") == 0:
                return body.get("data")
            log_event(logger, WARNING, "case_context_rejected",
                      trace_id=trace_id, status=response.status_code,
                      code=body.get("code"))
            return None
        except Exception as exc:  # noqa: BLE001
            log_event(logger, WARNING, "case_context_error",
                      trace_id=trace_id, error=type(exc).__name__, msg=str(exc))
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

    # ---------- 教材向量化入库完成回调（status: 2 成功 / 3 失败） ----------
    async def knowledge_callback(
        self,
        textbook_id: int,
        status: int,
        error: str | None = None,
        ingestion_id: str | None = None,
        trace_id: str = "-",
    ) -> bool:
        body: dict[str, Any] = {"textbookId": textbook_id, "status": status}
        if error:
            # 截断 + 换行折叠，避免异常堆栈/超长消息污染后端 JSON 与页面展示
            body["error"] = " ".join(error.split())[:500]
        if ingestion_id:
            body["ingestionId"] = str(ingestion_id)[:64]
        return await self._post("/api/internal/knowledge/callback", body, trace_id)

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

    # ---------- 5. 模型异常/降级/恢复事件 ----------
    async def log_model_event(
        self,
        event_type: str,
        model_name: str,
        error_message: str,
        detail: dict[str, Any] | None = None,
        trace_id: str = "-",
        capability: str = "",
        recovered: bool = False,
    ) -> bool:
        return await self._post(
            "/api/internal/model-event/log",
            {
                "eventType": event_type,
                "modelName": model_name,
                "capability": capability,
                "errorMessage": error_message,
                "detailJson": json.dumps(detail or {}, ensure_ascii=False),
                "traceId": trace_id,
                "recovered": recovered,
            },
            trace_id,
        )

    # ---------- 6. AI 学伴长期记忆抽取结果回调 ----------
    async def save_companion_memories(
        self,
        student_id: int,
        memories: list[dict[str, Any]],
        trace_id: str = "-",
    ) -> bool:
        """学伴对话结束后把抽取出的长期记忆回写业务中台（companion_memory 表）。

        失败静默（不阻塞学伴主流程），仅记日志。
        """
        return await self._post(
            "/api/internal/companion/memories",
            {"studentId": student_id, "facts": memories},
            trace_id,
        )

    # ---------- 7. Token 用量上报（V39） ----------
    async def report_token_usage(
        self,
        *,
        model: str,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_tokens: int = 0,
        latency_ms: int = 0,
        scene: str = "unknown",
        capability: str = "LLM",
        student_id: int | None = None,
        session_id: int | None = None,
        success: bool = True,
        is_stream: bool = False,
        trace_id: str = "-",
    ) -> bool:
        """把一次 LLM 调用的 token 消耗上报给业务中台落库。

        这是管理端「模型管理 → Token 管理」的唯一数据来源。
        失败静默：统计上报绝不能影响主调用链路。
        """
        body: dict[str, Any] = {
            "traceId": trace_id,
            "scene": scene,
            "capability": capability,
            "model": model,
            "promptTokens": max(0, int(prompt_tokens or 0)),
            "completionTokens": max(0, int(completion_tokens or 0)),
            "totalTokens": max(0, int(total_tokens or 0)),
            "latencyMs": max(0, int(latency_ms or 0)),
            "success": bool(success),
            "isStream": bool(is_stream),
        }
        if student_id is not None:
            body["studentId"] = student_id
        if session_id is not None:
            body["sessionId"] = session_id
        return await self._post("/api/internal/token-usage/report", body, trace_id)


# 模块级单例
backend_client = BackendClient()
