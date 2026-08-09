package com.zhiyu.config;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * SecurityConfig CORS 生产校验测试
 *
 * 验证生产环境（prod profile）拒绝通配符 CORS：
 *   - 空值 → 拒绝
 *   - 通配符 * → 拒绝（allowedOriginPatterns("*") + allowCredentials(true) 等于关闭 CORS 防护）
 *   - 包含 * 的通配模式 → 拒绝
 *   - 明确 Origin → 通过
 *
 * dev 环境允许通配符（开发便利）。
 */
class SecurityConfigCorsTest {

    private SecurityConfig createConfig(String[] origins, String profile) {
        SecurityConfig config = new SecurityConfig();
        ReflectionTestUtils.setField(config, "allowedOrigins", origins);
        ReflectionTestUtils.setField(config, "activeProfile", profile);
        return config;
    }

    @Test
    @DisplayName("prod + 通配符 * → 拒绝")
    void should_reject_wildcard_in_prod() {
        SecurityConfig config = createConfig(new String[]{"*"}, "prod");
        assertThatThrownBy(config::validateCors)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("不允许通配符");
    }

    @Test
    @DisplayName("prod + 包含 * 的模式 → 拒绝")
    void should_reject_wildcard_pattern_in_prod() {
        SecurityConfig config = createConfig(new String[]{"https://*.example.com"}, "prod");
        assertThatThrownBy(config::validateCors)
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("prod + 空值 → 拒绝")
    void should_reject_empty_in_prod() {
        SecurityConfig config = createConfig(new String[]{}, "prod");
        assertThatThrownBy(config::validateCors)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("必须配置");
    }

    @Test
    @DisplayName("prod + 明确 Origin → 通过")
    void should_allow_explicit_origins_in_prod() {
        SecurityConfig config = createConfig(
                new String[]{"https://admin.example.com", "https://teacher.example.com"}, "prod");
        assertThatCode(config::validateCors).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("dev + 通配符 * → 允许（开发便利）")
    void should_allow_wildcard_in_dev() {
        SecurityConfig config = createConfig(new String[]{"*"}, "dev");
        assertThatCode(config::validateCors).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("prod + 混合明确和通配 → 拒绝")
    void should_reject_mixed_origins_in_prod() {
        SecurityConfig config = createConfig(
                new String[]{"https://admin.example.com", "*"}, "prod");
        assertThatThrownBy(config::validateCors)
                .isInstanceOf(IllegalStateException.class);
    }
}
