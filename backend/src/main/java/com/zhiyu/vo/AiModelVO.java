package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * AI 模型管理列表/详情（管理端，apiKey 已脱敏）
 */
@Data
@Builder
public class AiModelVO {

    private Long id;

    private String name;

    private String provider;

    /** LLM / VISION / EMBEDDING / EMBEDDING_MULTI */
    private String capability;

    private String baseUrl;

    /** 脱敏后的密钥展示（如 sk-****abcd），无密钥则为 null */
    private String apiKey;

    /** 是否已配置密钥（用于编辑回显占位） */
    private Boolean hasApiKey;

    private String model;

    private Integer dimension;

    private Integer timeoutSeconds;

    private Integer maxTokens;

    private BigDecimal temperature;

    private Boolean isActive;

    /** 0停用 1启用 */
    private Integer status;

    private String description;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}