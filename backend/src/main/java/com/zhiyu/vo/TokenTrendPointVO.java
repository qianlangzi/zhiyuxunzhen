package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * Token 用量趋势点（按天聚合）
 */
@Data
@Builder
public class TokenTrendPointVO {

    /** 日期，格式 yyyy-MM-dd */
    private String label;

    private Long totalTokens;
    private Long promptTokens;
    private Long completionTokens;
    private Long calls;
}
