package com.zhiyu.service.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 模型 Token 配额保存请求
 */
@Data
public class TokenQuotaDTO {

    /** 主键，为空表示新增 */
    private Long id;

    @NotBlank(message = "模型标识不能为空")
    @Size(max = 128)
    private String model;

    /** 月度 token 上限，0 表示不限制 */
    @Min(value = 0, message = "配额不能为负数")
    private Long monthlyQuota;

    @Min(value = 1, message = "告警阈值需在 1-100 之间")
    @Max(value = 100, message = "告警阈值需在 1-100 之间")
    private Integer warnPercent;

    /** 1 启用 0 停用 */
    private Integer status;

    @Size(max = 255)
    private String remark;
}
