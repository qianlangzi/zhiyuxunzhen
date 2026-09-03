package com.zhiyu.config;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.Set;

/**
 * Spring Profile 合法性校验（fail-closed）
 *
 * 防止 application.yml 中 ${SPRING_PROFILES_ACTIVE} 在环境变量缺失时
 * 被解析为字面量 profile 名称（如 "${SPRING_PROFILES_ACTIVE}"），
 * 导致 application-dev/prod.yml 不加载、@Profile 注解失效。
 *
 * 要求恰好激活一个合法 profile（dev/test/prod）：
 *   - 防止 prod,dev 同时激活（DataInitializer 和 ProdSecurityInitializer 并存，无顺序保证）
 *   - 防止 prod,evil 等非法组合绕过校验
 *   - 防止字面量 "${SPRING_PROFILES_ACTIVE}" 被当作合法 profile
 */
@Slf4j
@Component
public class ProfileValidator {

    private static final Set<String> VALID_PROFILES = Set.of("dev", "test", "prod");

    @Autowired
    private Environment environment;

    @PostConstruct
    public void validate() {
        String[] active = environment.getActiveProfiles();
        if (active.length != 1 || !VALID_PROFILES.contains(active[0])) {
            throw new IllegalStateException(
                "必须恰好激活一个合法 Spring Profile（dev/test/prod）。" +
                "请通过 SPRING_PROFILES_ACTIVE 环境变量设置唯一值，" +
                "禁止多 profile 组合（如 prod,dev）。" +
                "当前激活的 profiles: " + Arrays.toString(active)
            );
        }
        log.info("Profile 校验通过，活跃 profile: {}", active[0]);
    }
}
