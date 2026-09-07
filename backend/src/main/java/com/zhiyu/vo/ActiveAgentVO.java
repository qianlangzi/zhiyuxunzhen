package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

/**
 * AI 中台活跃 Agent 元参数（内部接口 /api/internal/agent/active 返回）
 * 走内网信任边界（X-Internal-Token 鉴权）。
 */
@Data
@Builder
public class ActiveAgentVO {
    private Long id;
    /** Agent 逻辑键 */
    private String code;
    private String name;
    /** 引用的提示词逻辑键 */
    private String promptName;
    /** system prompt 直接覆盖文本 */
    private String promptOverride;
    /** 采样温度覆盖 */
    private BigDecimal temperature;
    /** 最大 tokens 覆盖 */
    private Integer maxTokens;
    /** 启用工具（rag/vision/...） */
    private String toolsConfig;
    /** 执行策略（CODE/TOOL/LOOP，空=内置默认 CODE） */
    private String strategy;
    /** 指定模型（空用全局默认） */
    private String model;
    /** TOOL/LOOP 策略最大循环轮数 */
    private Integer maxIterations;
    /** 是否启用（由 status==1 派生，供 AI 网关 spec.enabled 判断拦截停用 Agent） */
    private Boolean enabled;
}