import pytest

from app.adapters.object_storage import LocalObjectStorage
from app.core.errors import OutputSchemaInvalidError


@pytest.mark.asyncio
async def test_local_object_storage_reads_only_inside_root(tmp_path):
    target = tmp_path / "textbooks" / "book.pdf"
    target.parent.mkdir()
    target.write_bytes(b"pdf")
    storage = LocalObjectStorage(tmp_path, max_bytes=100)
    assert await storage.read("textbooks/book.pdf") == b"pdf"


@pytest.mark.asyncio
async def test_local_object_storage_rejects_traversal(tmp_path):
    storage = LocalObjectStorage(tmp_path)
    with pytest.raises(OutputSchemaInvalidError):
        await storage.read("../secret.pdf")


@pytest.mark.asyncio
async def test_local_object_storage_rejects_oversized_object(tmp_path):
    target = tmp_path / "large.pdf"
    target.write_bytes(b"1234")
    storage = LocalObjectStorage(tmp_path, max_bytes=3)
    with pytest.raises(OutputSchemaInvalidError):
        await storage.read("large.pdf")
