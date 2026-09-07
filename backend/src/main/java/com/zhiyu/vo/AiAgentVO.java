package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class AiAgentVO {
    private Long id;
    private String code;
    private String name;
    private String description;
    private String promptName;
    private String promptOverride;
    private BigDecimal temperature;
    private Integer maxTokens;
    private String toolsConfig;
    private String strategy;
    private String model;
    private Integer maxIterations;
    private Boolean isActive;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}