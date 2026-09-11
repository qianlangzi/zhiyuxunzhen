"""备课素材图片引用的回归测试（2026-09-11）。

背景：`lesson_material.file_url` 存的是**相对路径**（`/uploads/materials/x.png`，
由 docker-compose 的 `UPLOAD_BASE_URL=/uploads` 决定）。旧实现把相对路径直接交给
第三方 VLM，`urlparse` 取不到 scheme/hostname → 直接 `return ""` → **备课图片永远
不会被识别**，教案里只留标题锚点，还会误报「VLM 未配置或不可用」。

修复：后端上传目录（`/app/data/objects`）与 AI 的 `object_storage_root` 是同一份
host 目录（只读挂载），因此相对路径改为**本地读取 + base64 内联**；外链仍走问诊
同款来源白名单，避免把任意 URL 变成 SSRF 跳板。

本文件锁死这两条语义。
"""
from __future__ import annotations

from app.api.lesson import _material_image_ref
from app.core.config import settings

PNG_1PX = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02"
    b"\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf\xc0\x00\x00\x03\x01"
    b"\x01\x00\x18\xdd\x8d\xb0\x00\x00\x00\x00IEND\xaeB`\x82"
)


def _write_material(tmp_path, name: str, data: bytes = PNG_1PX) -> str:
    """把素材写进 object_storage_root/materials，返回后端会返回的相对 URL。"""
    materials = tmp_path / "materials"
    materials.mkdir(parents=True, exist_ok=True)
    (materials / name).write_bytes(data)
    return f"/uploads/materials/{name}"


def test_relative_upload_path_becomes_data_url(monkeypatch, tmp_path):
    """相对上传路径 → 本地读取并内联为 data URL（修复的核心行为）。"""
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    url = _write_material(tmp_path, "a.png")
    ref = _material_image_ref(url)
    assert ref.startswith("data:image/png;base64,")
    assert len(ref) > len("data:image/png;base64,")


def test_jpeg_extension_maps_to_jpeg_mime(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    ref = _material_image_ref(_write_material(tmp_path, "b.jpg"))
    assert ref.startswith("data:image/jpeg;base64,")


def test_missing_file_returns_empty(monkeypatch, tmp_path):
    """素材文件不存在时降级为空（教案退回标题锚点），不能抛异常。"""
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    assert _material_image_ref("/uploads/materials/not-exist.png") == ""


def test_path_traversal_is_rejected(monkeypatch, tmp_path):
    """目录穿越必须被拦（相对片段里不允许 .. ）。"""
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    assert _material_image_ref("/uploads/../../etc/passwd") == ""
    assert _material_image_ref("/uploads/materials/../../secret.png") == ""


def test_unsupported_extension_returns_empty(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    assert _material_image_ref(_write_material(tmp_path, "c.pdf")) == ""


def test_oversize_material_returns_empty(monkeypatch, tmp_path):
    """超大素材放弃内联，避免 base64 撑爆上下文/请求体。"""
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    big = _write_material(tmp_path, "big.png", b"\x89PNG" + b"0" * (9 * 1024 * 1024))
    assert _material_image_ref(big) == ""


def test_external_url_enforces_vision_whitelist_in_prod(monkeypatch, tmp_path):
    """外链走与问诊读图同一套白名单：prod 非白名单主机一律拒绝。"""
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    monkeypatch.setattr(settings, "env", "prod")
    monkeypatch.setattr(settings, "vision_allowed_hosts", ["http://8.160.161.158"])
    assert _material_image_ref("http://evil.example.com/x.png") == ""
    assert _material_image_ref("http://8.160.161.158/uploads/materials/x.png") == (
        "http://8.160.161.158/uploads/materials/x.png"
    )


def test_external_absolute_url_passthrough_in_dev(monkeypatch, tmp_path):
    """dev 不校验来源（与问诊读图一致），公网外链原样透传。"""
    monkeypatch.setattr(settings, "object_storage_root", str(tmp_path))
    monkeypatch.setattr(settings, "env", "dev")
    absolute = "http://example.com/a.png"
    assert _material_image_ref(absolute) == absolute
