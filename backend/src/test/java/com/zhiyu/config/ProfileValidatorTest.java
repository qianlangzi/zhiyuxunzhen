package com.zhiyu.config;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.Environment;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * ProfileValidator 单元测试
 *
 * 验证 fail-closed 策略：
 *   - 恰好一个合法 profile（dev/test/prod）→ 通过
 *   - 多 profile 组合（prod,dev）→ 拒绝
 *   - 字面量 ${SPRING_PROFILES_ACTIVE} → 拒绝
 *   - 非法 profile → 拒绝
 *   - 无 profile → 拒绝
 */
class ProfileValidatorTest {

    private ProfileValidator createValidator(String... profiles) {
        Environment env = mock(Environment.class);
        when(env.getActiveProfiles()).thenReturn(profiles);
        ProfileValidator validator = new ProfileValidator();
        ReflectionTestUtils.setField(validator, "environment", env);
        return validator;
    }

    @Test
    @DisplayName("dev 单一 profile → 通过")
    void should_pass_dev_profile() {
        ProfileValidator validator = createValidator("dev");
        assertThatCode(validator::validate).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("prod 单一 profile → 通过")
    void should_pass_prod_profile() {
        ProfileValidator validator = createValidator("prod");
        assertThatCode(validator::validate).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("test 单一 profile → 通过")
    void should_pass_test_profile() {
        ProfileValidator validator = createValidator("test");
        assertThatCode(validator::validate).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("多 profile 组合（prod,dev）→ 拒绝")
    void should_reject_multiple_profiles() {
        ProfileValidator validator = createValidator("prod", "dev");
        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("必须恰好激活一个合法 Spring Profile");
    }

    @Test
    @DisplayName("prod,evil 组合 → 拒绝")
    void should_reject_prod_evil_combination() {
        ProfileValidator validator = createValidator("prod", "evil");
        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("字面量 ${SPRING_PROFILES_ACTIVE} → 拒绝")
    void should_reject_literal_placeholder() {
        ProfileValidator validator = createValidator("${SPRING_PROFILES_ACTIVE}");
        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("非法 profile（evil）→ 拒绝")
    void should_reject_invalid_profile() {
        ProfileValidator validator = createValidator("evil");
        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("无 profile → 拒绝")
    void should_reject_empty_profiles() {
        ProfileValidator validator = createValidator();
        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class);
    }
}
