package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * Token 用量总览（管理端 Token 管理页顶部指标）
 */
@Data
@Builder
public class TokenOverviewVO {

    private Long todayTokens;
    private Long monthTokens;
    private Long totalTokens;

    private Long todayCalls;
    private Long monthCalls;

    /** 本月平均耗时（毫秒） */
    private Long avgLatencyMs;

    /** 本月失败调用数 */
    private Long monthFailedCalls;

    /** 已配置配额模型的本月合计上限；未配置任何配额时为 0 */
    private Long monthQuota;

    /** 本月用量占配额百分比；无配额时为 null（前端不展示进度条） */
    private Integer monthUsedPercent;

    /** 已触发告警（用量 ≥ 阈值）的模型列表 */
    private List<TokenQuotaAlertVO> alerts;
}
