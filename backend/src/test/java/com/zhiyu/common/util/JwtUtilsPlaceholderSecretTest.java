package com.zhiyu.common.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * JwtUtils 占位密钥拒绝测试
 *
 * 验证生产环境（prod profile）拒绝所有历史公开占位密钥：
 *   - dev-only-secret-key-32chars-minimum-aaaa（当前 dev 默认值）
 *   - please-change-me-to-a-random-32-char-string（历史占位值，43 字节）
 *   - test-secret-key-32chars-minimum-aaaa（测试占位值）
 *
 * 同时验证 dev 环境允许使用占位密钥（开发便利性）。
 */
class JwtUtilsPlaceholderSecretTest {

    private JwtUtils createJwtUtils(String secret, String profile) {
        JwtUtils jwtUtils = new JwtUtils();
        ReflectionTestUtils.setField(jwtUtils, "secret", secret);
        ReflectionTestUtils.setField(jwtUtils, "expireHours", 24L);
        ReflectionTestUtils.setField(jwtUtils, "refreshExpireHours", 168L);
        ReflectionTestUtils.setField(jwtUtils, "activeProfile", profile);
        return jwtUtils;
    }

    @Test
    @DisplayName("prod + dev-only 占位密钥 → 拒绝启动")
    void should_reject_dev_only_placeholder_in_prod() {
        JwtUtils jwtUtils = createJwtUtils(
                "dev-only-secret-key-32chars-minimum-aaaa", "prod");
        assertThatThrownBy(jwtUtils::init)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("公开占位密钥");
    }

    @Test
    @DisplayName("prod + please-change-me 占位密钥(43字节) → 拒绝启动")
    void should_reject_please_change_placeholder_in_prod() {
        JwtUtils jwtUtils = createJwtUtils(
                "please-change-me-to-a-random-32-char-string", "prod");
        assertThatThrownBy(jwtUtils::init)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("公开占位密钥");
    }

    @Test
    @DisplayName("prod + test 占位密钥 → 拒绝启动")
    void should_reject_test_placeholder_in_prod() {
        JwtUtils jwtUtils = createJwtUtils(
                "test-secret-key-32chars-minimum-aaaa", "prod");
        assertThatThrownBy(jwtUtils::init)
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("dev + dev-only 占位密钥 → 允许启动（开发便利）")
    void should_allow_placeholder_in_dev() {
        JwtUtils jwtUtils = createJwtUtils(
                "dev-only-secret-key-32chars-minimum-aaaa", "dev");
        assertThatCode(jwtUtils::init).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("prod + 随机强密钥 → 允许启动")
    void should_allow_strong_secret_in_prod() {
        JwtUtils jwtUtils = createJwtUtils(
                "a-very-strong-random-secret-key-32bytes!", "prod");
        assertThatCode(jwtUtils::init).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("短于 32 字节的密钥 → 拒绝启动（任何 profile）")
    void should_reject_short_secret() {
        JwtUtils jwtUtils = createJwtUtils("short-secret", "dev");
        assertThatThrownBy(jwtUtils::init)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("长度不足 32 字节");
    }
}
