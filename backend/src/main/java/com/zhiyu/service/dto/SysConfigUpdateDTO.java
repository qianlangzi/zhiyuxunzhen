package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 系统配置更新请求（PRD 4.16）
 */
@Data
public class SysConfigUpdateDTO {

    @NotBlank(message = "配置键不能为空")
    private String configKey;

    @NotBlank(message = "配置值不能为空")
    private String configValue;

    /** MODEL / SAFETY / DAILY_CASE / TOKEN_BUDGET */
    private String configType;
}
