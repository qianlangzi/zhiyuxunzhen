package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * Token 消耗排行项（按模型或场景聚合）
 */
@Data
@Builder
public class TokenRankVO {

    /** 模型名或场景名，取决于查询维度 */
    private String name;

    private Long totalTokens;
    private Long promptTokens;
    private Long completionTokens;
    private Long calls;
    private Long avgLatencyMs;

    /** 占总量百分比（整数） */
    private Integer percent;
}
