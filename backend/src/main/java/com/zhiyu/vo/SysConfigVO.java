package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 系统配置查询结果（PRD 4.16）
 */
@Data
@Builder
public class SysConfigVO {

    private Long id;

    private String configKey;

    private String configValue;

    /** MODEL / SAFETY / DAILY_CASE / TOKEN_BUDGET */
    private String configType;

    private LocalDateTime updatedAt;
}