"""Vision 图片 URL 来源校验的回归测试。

背景：生产环境曾出现「病例问诊图片发不出去」，根因是两道门同时误伤——
  1) VISION_ALLOWED_HOSTS 里运维按 URL 习惯写成 ``http://8.160.161.158``，
     而校验侧用 ``urlparse(url).hostname``（裸主机名）做集合比较 → 永远 403；
  2) 生产强制 HTTPS，但自建对象存储只有 ``http://8.160.161.158`` 入口 → 422。

修复思路：白名单条目「自带协议」——裸主机名默认只允许 https，写成完整 URL
则按其中的协议放行。本文件锁死该行为，并确保白名单之外的主机与内网地址
仍然被拦截（安全边界不能被放松）。
"""
from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.api.vision import _validate_image_url
from app.core.config import settings

PROD_HTTP_IMG = "http://8.160.161.158/zhiyu/case/x.png"


@pytest.fixture(autouse=True)
def _prod_vision(monkeypatch):
    """把 settings 置为生产多模态形态（与线上 .env 一致），测完自动还原。"""
    monkeypatch.setattr(settings, "env", "prod")
    monkeypatch.setattr(settings, "vision_allowed_hosts", ["http://8.160.161.158"])
    yield


# ---------------------------------------------------------------- 白名单归一化
def test_whitelist_url_form_matches_http_image():
    """白名单写 http://host 时应放行 http://host/path 的图片（修复前 403）。"""
    assert _validate_image_url(PROD_HTTP_IMG) == PROD_HTTP_IMG


def test_whitelist_normalizes_port_path_case_and_trailing_dot(monkeypatch):
    """带端口、带路径、大写、末尾点等写法都应归一化后命中。"""
    monkeypatch.setattr(
        settings, "vision_allowed_hosts",
        ["https://8.160.161.158:8443/a/b", "STORAGE.Example.COM."],
    )
    assert _validate_image_url("https://8.160.161.158/x.png")
    assert _validate_image_url("https://storage.example.com/x.png")


def test_allowed_origins_property_shape():
    """property 产出 {主机名: 允许协议集合}。"""
    assert settings.vision_allowed_origins == {"8.160.161.158": {"http"}}


def test_bare_hostname_defaults_to_https_only(monkeypatch):
    """未写协议时按 https 处理：HTTPS 放行、HTTP 拦截。"""
    monkeypatch.setattr(settings, "vision_allowed_hosts", ["8.160.161.158"])
    assert _validate_image_url("https://8.160.161.158/x.png")
    with pytest.raises(HTTPException) as exc:
        _validate_image_url(PROD_HTTP_IMG)
    assert exc.value.status_code == 422


def test_same_host_merges_schemes_when_listed_twice(monkeypatch):
    monkeypatch.setattr(settings, "vision_allowed_hosts", ["8.160.161.158", "http://8.160.161.158"])
    assert settings.vision_allowed_origins == {"8.160.161.158": {"http", "https"}}


def test_blank_entries_ignored(monkeypatch):
    monkeypatch.setattr(settings, "vision_allowed_hosts", ["", "   ", "8.160.161.158"])
    assert settings.vision_allowed_origins == {"8.160.161.158": {"https"}}


# ---------------------------------------------------------------- 安全边界
def test_host_outside_whitelist_rejected():
    with pytest.raises(HTTPException) as exc:
        _validate_image_url("http://evil.example.com/x.png")
    assert exc.value.status_code == 403


def test_private_address_rejected_even_when_whitelisted_scheme_allows_http():
    with pytest.raises(HTTPException) as exc:
        _validate_image_url("http://192.168.1.10/x.png")
    assert exc.value.status_code == 422


def test_localhost_credentials_and_bad_scheme_rejected():
    for bad in (
        "http://localhost/x.png",
        "file:///etc/passwd",
        "http://user:pw@8.160.161.158/x.png",
    ):
        with pytest.raises(HTTPException):
            _validate_image_url(bad)


def test_dev_mode_skips_whitelist(monkeypatch):
    """非生产环境不启用白名单，公网地址直接放行。"""
    monkeypatch.setattr(settings, "env", "dev")
    assert _validate_image_url("https://any-public.example.com/x.png")
