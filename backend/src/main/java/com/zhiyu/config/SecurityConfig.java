package com.zhiyu.config;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 安全与 CORS 配置（PRD 10.3 / 16.3.1）
 * PasswordEncoder 声明为 Bean，统一强度配置
 * CORS 按 zhiyu.cors.allowed-origins 配置白名单
 *
 * 生产环境（prod profile）启动时校验 CORS 白名单：
 *   - 拒绝空值
 *   - 拒绝通配符 *（allowedOriginPatterns("*") + allowCredentials(true) 等于完全关闭 CORS 防护）
 *   - 拒绝包含 * 的通配模式
 */
@Slf4j
@Configuration
public class SecurityConfig implements WebMvcConfigurer {

    @Value("${zhiyu.cors.allowed-origins:*}")
    private String[] allowedOrigins;

    @Value("${spring.profiles.active:}")
    private String activeProfile;

    @PostConstruct
    public void validateCors() {
        if (!"prod".equals(activeProfile)) {
            return;
        }
        if (allowedOrigins == null || allowedOrigins.length == 0) {
            throw new IllegalStateException("生产环境必须配置 CORS_ALLOWED_ORIGINS（逗号分隔的明确 Origin）");
        }
        for (String origin : allowedOrigins) {
            if (origin == null || origin.trim().isEmpty() || "*".equals(origin.trim()) || origin.contains("*")) {
                throw new IllegalStateException(
                        "生产环境 CORS_ALLOWED_ORIGINS 不允许通配符 *，必须设置明确的 Origin: " + origin
                );
            }
        }
        log.info("生产环境 CORS 白名单校验通过: {} 个 Origin", allowedOrigins.length);
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns(allowedOrigins)
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }
}
