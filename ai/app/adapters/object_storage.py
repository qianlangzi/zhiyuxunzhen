"""受控对象存储读取接口。

当前实现使用本地根目录，生产替换为 S3/MinIO/OSS 时保持 `read` 契约不变。
"""
from pathlib import Path, PurePosixPath

from app.core.config import settings
from app.core.errors import OutputSchemaInvalidError


class LocalObjectStorage:
    def __init__(self, root: str | Path | None = None, max_bytes: int | None = None) -> None:
        self.root = Path(root or settings.object_storage_root).resolve()
        self.max_bytes = max_bytes or settings.object_storage_max_bytes

    def resolve(self, object_key: str) -> Path:
        key = PurePosixPath(object_key.replace("\\", "/"))
        if key.is_absolute() or ".." in key.parts or not key.parts:
            raise OutputSchemaInvalidError("objectKey 格式不安全")
        target = (self.root / Path(*key.parts)).resolve()
        if target != self.root and self.root not in target.parents:
            raise OutputSchemaInvalidError("objectKey 超出对象存储根目录")
        return target

    async def read(self, object_key: str) -> bytes:
        target = self.resolve(object_key)
        if not target.is_file():
            raise OutputSchemaInvalidError("对象不存在")
        size = target.stat().st_size
        if size <= 0 or size > self.max_bytes:
            raise OutputSchemaInvalidError("对象为空或超过大小限制")
        return target.read_bytes()


object_storage = LocalObjectStorage()
