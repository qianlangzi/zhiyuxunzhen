"""教材图片索引服务（生成侧多模态的基础设施）

职责：
  1. chunk_id → 图片文件映射（JSON 索引 + 图片文件持久化，容器重启不丢）
     —— MMORE/PyMuPDF 提取的图片原本存临时目录会被清理，本服务把它们
        持久化并维护映射，检索命中后可回查原图
  2. VLM 图述生成（带内存缓存）：生成答案时把命中 chunk 的图片交给
     qwen3-omni-flash 生成医学描述，并入 LLM 生成上下文

设计：
  - 独立目录 ./data/textbook-images（不依赖 object_storage：开发容器内
    objects 目录为只读挂载，无法写入）
  - 并发写保护：asyncio.Lock；写入失败仅告警不阻断入库
"""
import asyncio
import json
import os
from typing import Any

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING

logger = get_logger(__name__)

_IMAGE_DIR = os.path.join("data", "textbook-images")


class ImageIndexService:
    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._index_path = os.path.join(_IMAGE_DIR, "index.json")
        self._captions_path = os.path.join(_IMAGE_DIR, "captions.json")
        self._index: dict[str, dict[str, Any]] = {}
        self._loaded = False
        self._captions: dict[str, str] = {}  # image_key -> VLM 图述缓存

    def _load_sync(self) -> None:
        try:
            if os.path.isfile(self._index_path):
                with open(self._index_path, encoding="utf-8") as f:
                    self._index = json.load(f)
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "image_index_load_error", error=type(e).__name__)
            self._index = {}
        # 图述缓存持久化：重启后不丢失，避免重启后首批问诊每图多 1-3s VLM 调用
        try:
            if os.path.isfile(self._captions_path):
                with open(self._captions_path, encoding="utf-8") as f:
                    self._captions = json.load(f)
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "image_captions_load_error", error=type(e).__name__)
            self._captions = {}
        self._loaded = True

    async def _ensure_loaded(self) -> None:
        if not self._loaded:
            await asyncio.to_thread(self._load_sync)

    async def register(
        self,
        chunk_id: str,
        image_bytes: bytes,
        ext: str,
        meta: dict[str, Any] | None = None,
    ) -> str | None:
        """把图片持久化并登记映射，返回 image_key；失败返回 None（不阻断入库）。"""
        image_key = f"{chunk_id}.{ext or 'png'}"
        path = os.path.join(_IMAGE_DIR, image_key)

        def _write() -> None:
            os.makedirs(_IMAGE_DIR, exist_ok=True)
            with open(path, "wb") as f:
                f.write(image_bytes)

        try:
            await asyncio.to_thread(_write)
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "image_persist_failed",
                      chunk_id=chunk_id, error=type(e).__name__)
            return None

        await self._ensure_loaded()
        async with self._lock:
            self._index[chunk_id] = {"key": image_key, **(meta or {})}
            await asyncio.to_thread(self._persist_sync)
        return image_key

    def _persist_sync(self) -> None:
        try:
            os.makedirs(_IMAGE_DIR, exist_ok=True)
            tmp = self._index_path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(self._index, f, ensure_ascii=False)
            os.replace(tmp, self._index_path)
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "image_index_persist_error", error=type(e).__name__)

    async def lookup(self, chunk_id: str) -> str | None:
        """查 chunk 关联的图片 key"""
        await self._ensure_loaded()
        entry = self._index.get(chunk_id)
        return entry.get("key") if entry else None

    async def read(self, image_key: str) -> bytes | None:
        """读取图片字节（以图搜图/前端展示用）；文件不存在返回 None"""
        if not image_key:
            return None
        path = os.path.join(_IMAGE_DIR, os.path.basename(image_key))
        if not os.path.isfile(path):
            return None
        try:
            return await asyncio.to_thread(
                lambda: open(path, "rb").read()  # noqa: SIM115
            )
        except Exception:  # noqa: BLE001
            return None

    async def caption(self, image_key: str, context: str = "", trace_id: str = "-") -> str:
        """生成图片的 VLM 医学描述（内存+磁盘缓存，一次生成终身复用）。

        VLM 未配置时返回空字符串，调用方跳过图述增强。
        """
        if not settings.vision_configured or not settings.image_caption_enabled:
            return ""
        await self._ensure_loaded()
        if image_key in self._captions:
            return self._captions[image_key]

        import base64

        path = os.path.join(_IMAGE_DIR, image_key)
        if not os.path.isfile(path):
            return ""

        def _read() -> bytes:
            with open(path, "rb") as f:
                return f.read()

        try:
            img_bytes = await asyncio.to_thread(_read)
        except Exception:  # noqa: BLE001
            return ""
        ext = os.path.splitext(image_key)[1].lower().lstrip(".")
        mime = "image/png" if ext == "png" else "image/jpeg"
        b64 = base64.b64encode(img_bytes).decode("utf-8")

        from openai import AsyncOpenAI

        client = AsyncOpenAI(
            base_url=settings.vision_base_url,
            api_key=settings.vision_api_key.get_secret_value(),
            timeout=30.0,
        )
        try:
            resp = await asyncio.wait_for(
                client.chat.completions.create(
                    model=settings.vision_model,
                    messages=[{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": (
                                "请用 2-3 句话客观描述这张医学教材图片的关键信息"
                                + (f"（上下文：{context[:100]}）" if context else "")
                                + "，例如图形类型、关键结构/波形特征。只输出描述本身。"
                            )},
                            {"type": "image_url", "image_url": {
                                "url": f"data:{mime};base64,{b64}",
                            }},
                        ],
                    }],
                    max_tokens=200,
                    temperature=0.1,
                ),
                timeout=20.0,
            )
            text = (resp.choices[0].message.content or "").strip()
            if text:
                self._captions[image_key] = text
                async with self._lock:
                    await asyncio.to_thread(self._persist_captions_sync)
                log_event(logger, INFO, "image_caption_generated",
                          trace_id=trace_id, image_key=image_key, chars=len(text))
            return text
        except Exception as e:  # noqa: BLE001 - 图述失败不阻断生成
            log_event(logger, WARNING, "image_caption_error",
                      trace_id=trace_id, image_key=image_key, error=type(e).__name__)
            return ""

    def _persist_captions_sync(self) -> None:
        try:
            os.makedirs(_IMAGE_DIR, exist_ok=True)
            tmp = self._captions_path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(self._captions, f, ensure_ascii=False)
            os.replace(tmp, self._captions_path)
        except Exception as e:  # noqa: BLE001
            log_event(logger, WARNING, "image_captions_persist_error", error=type(e).__name__)


image_index_service = ImageIndexService()
