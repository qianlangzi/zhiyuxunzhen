package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 模型 Token 配额（含本月已用量与告警状态）
 */
@Data
@Builder
public class TokenQuotaVO {

    private Long id;
    private String model;

    /** 月度 token 上限，0 表示不限制 */
    private Long monthlyQuota;

    private Integer warnPercent;

    /** 1 启用 0 停用 */
    private Integer status;

    private String remark;

    /** 本月已用 token */
    private Long usedTokens;

    /** 本月用量占配额百分比；配额为 0（不限）时为 null */
    private Integer usedPercent;

    /** 是否已达告警阈值 */
    private Boolean warning;

    /** 是否已超额 */
    private Boolean exceeded;
}
