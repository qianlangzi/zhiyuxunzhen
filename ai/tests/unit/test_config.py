"""验证环境变量映射到 Settings 字段的正确性

这是上线门禁测试，不是可选优化。
当前项目已暴露 AI_INTERNAL_TOKEN 和 ENV_MODE 未映射到 FastAPI 字段的问题。
"""
import os
import pytest
from pydantic_settings import BaseSettings


def test_env_mode_maps_to_env(monkeypatch):
    """ENV_MODE 环境变量应映射到 settings.env"""
    monkeypatch.setenv("ENV_MODE", "prod")
    monkeypatch.setenv("JWT_SECRET", "real-secret-key-32chars-minimum-aaaa")
    monkeypatch.setenv("AI_INTERNAL_TOKEN", "real-internal-token")
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", '["https://example.com"]')
    monkeypatch.setenv("VISION_ALLOWED_HOSTS", '["storage.example.com"]')
    monkeypatch.setenv("OPS_TOKEN", "real-ops-token")
    monkeypatch.setenv("ENABLE_LLM_FALLBACK", "false")
    monkeypatch.setenv("ENABLE_MILVUS_FALLBACK", "false")
    # Clear lru_cache to get fresh settings
    from app.core.config import get_settings
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.env == "prod"


def test_ai_internal_token_maps_to_internal_token(monkeypatch):
    """AI_INTERNAL_TOKEN 环境变量应映射到 settings.internal_token"""
    monkeypatch.setenv("AI_INTERNAL_TOKEN", "my-secret-token")
    monkeypatch.setenv("ENV_MODE", "dev")
    from app.core.config import get_settings
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.internal_token.get_secret_value() == "my-secret-token"


def test_jwt_secret_maps_correctly(monkeypatch):
    """JWT_SECRET 环境变量应映射到 settings.jwt_secret"""
    monkeypatch.setenv("JWT_SECRET", "my-jwt-secret")
    monkeypatch.setenv("ENV_MODE", "dev")
    from app.core.config import get_settings
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.jwt_secret.get_secret_value() == "my-jwt-secret"


def test_enable_llm_fallback_maps_correctly(monkeypatch):
    """ENABLE_LLM_FALLBACK 环境变量应映射到 settings.enable_llm_fallback"""
    monkeypatch.setenv("ENABLE_LLM_FALLBACK", "false")
    monkeypatch.setenv("ENV_MODE", "dev")
    from app.core.config import get_settings
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.enable_llm_fallback is False


def test_prod_rejects_default_jwt_secret(monkeypatch):
    """生产环境应拒绝默认 JWT 密钥"""
    monkeypatch.setenv("ENV_MODE", "prod")
    monkeypatch.setenv("JWT_SECRET", "dev-only-secret-key-32chars-minimum-aaaa")
    monkeypatch.setenv("AI_INTERNAL_TOKEN", "real-token")
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", '["https://example.com"]')
    monkeypatch.setenv("VISION_ALLOWED_HOSTS", '["storage.example.com"]')
    from app.core.config import get_settings, Settings
    get_settings.cache_clear()
    with pytest.raises(Exception):
        Settings()


def test_prod_rejects_default_internal_token(monkeypatch):
    """生产环境应拒绝默认内部 Token"""
    monkeypatch.setenv("ENV_MODE", "prod")
    monkeypatch.setenv("JWT_SECRET", "real-secret-key-32chars-minimum-aaaa")
    monkeypatch.setenv("AI_INTERNAL_TOKEN", "dev-internal-token")
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", '["https://example.com"]')
    monkeypatch.setenv("VISION_ALLOWED_HOSTS", '["storage.example.com"]')
    from app.core.config import get_settings, Settings
    get_settings.cache_clear()
    with pytest.raises(Exception):
        Settings()


def test_prod_rejects_wildcard_cors(monkeypatch):
    """生产环境应拒绝 CORS 通配符"""
    monkeypatch.setenv("ENV_MODE", "prod")
    monkeypatch.setenv("JWT_SECRET", "real-secret-key-32chars-minimum-aaaa")
    monkeypatch.setenv("AI_INTERNAL_TOKEN", "real-token")
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", '["*"]')
    monkeypatch.setenv("VISION_ALLOWED_HOSTS", '["storage.example.com"]')
    from app.core.config import get_settings, Settings
    get_settings.cache_clear()
    with pytest.raises(Exception):
        Settings()


def test_prod_rejects_synthetic_fallback(monkeypatch):
    """Production must not expose the current synthetic fallback responses."""
    monkeypatch.setenv("ENV_MODE", "prod")
    monkeypatch.setenv("JWT_SECRET", "real-secret-key-32chars-minimum-aaaa")
    monkeypatch.setenv("AI_INTERNAL_TOKEN", "real-token")
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", '["https://example.com"]')
    monkeypatch.setenv("VISION_ALLOWED_HOSTS", '["storage.example.com"]')
    monkeypatch.setenv("VISION_ALLOWED_HOSTS", '["storage.example.com"]')
    monkeypatch.setenv("ENABLE_LLM_FALLBACK", "true")
    from app.core.config import Settings
    with pytest.raises(Exception):
        Settings()
