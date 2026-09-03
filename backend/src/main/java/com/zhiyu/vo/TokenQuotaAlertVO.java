package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 配额告警项（总览页顶部横幅）
 */
@Data
@Builder
public class TokenQuotaAlertVO {

    private String model;

    private Long usedTokens;

    private Long monthlyQuota;

    private Integer usedPercent;

    /** warning：达到阈值未超额；exceeded：已超额 */
    private String level;
}
