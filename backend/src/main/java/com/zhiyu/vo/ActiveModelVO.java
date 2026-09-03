package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

/**
 * AI 中台活跃模型配置（内部接口 /api/internal/model/active 返回）
 *
 * 该 VO 供 AI 服务运行时拉取「当前启用且激活」的模型真实配置，
 * 走内网信任边界（X-Internal-Token 鉴权），apiKey 为明文。
 */
@Data
@Builder
public class ActiveModelVO {

    private Long id;

    /** LLM / VISION / EMBEDDING / EMBEDDING_MULTI */
    private String capability;

    private String baseUrl;

    private String apiKey;

    private String model;

    private Integer dimension;

    private Integer timeoutSeconds;

    private Integer maxTokens;

    private BigDecimal temperature;
}