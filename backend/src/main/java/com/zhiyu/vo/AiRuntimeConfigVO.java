package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class AiRuntimeConfigVO {
    private Long id;
    private String configKey;
    private String configName;
    private String description;
    private String configType;
    private String value;
    private String defaultValue;
    private String min;
    private String max;
    private String step;
    private Boolean isActive;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}