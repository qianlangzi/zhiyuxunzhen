package com.zhiyu.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

/**
 * RestTemplate 配置（PRD 9.3）
 * 用于调用 AI 中台 FastAPI 接口
 * connectTimeout=5s, readTimeout=120s
 *
 * readTimeout 原为 30s，但 LLM 生成（如 SP 病例草稿）耗时不稳，首次冷启动可能
 * 超过 30s，会被后端提前截断返回"AI服务调用异常"，误表现为"网络超时"。
 * 放宽到 120s 覆盖绝大多数 AI 调用窗口后仍不会无限挂起。
 */
@Configuration
public class RestTemplateConfig {

    @Bean
    public RestTemplate restTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(5000);
        factory.setReadTimeout(120000);
        return new RestTemplate(factory);
    }
}
