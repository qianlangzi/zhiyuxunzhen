package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

/**
 * AI Agent 元参数管理（AI 配置中心 · Agent 行为参数热改）
 *
 * 管理 Agent 的「行为参数」层：引用哪个 system prompt、采样温度/最大 tokens 覆盖、
 * 是否启用哪些工具。执行编排逻辑仍留在 AI 中台代码，符合元参数层边界。
 * code 为逻辑键，同一 code 下至多一个 is_active=1。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("ai_agent")
public class AiAgent extends BaseEntity {

    /** Agent 逻辑键（与 AI 中台 agent 代码名对齐） */
    private String code;

    /** 显示名称 */
    private String name;

    /** 职责说明 */
    private String description;

    /** 引用的提示词逻辑键（默认同名） */
    private String promptName;

    /** system prompt 直接覆盖文本（非空时优先于 promptName 命中项生效） */
    private String promptOverride;

    /** 采样温度覆盖（留空用全局） */
    private BigDecimal temperature;

    /** 最大生成 tokens 覆盖（留空用全局） */
    private Integer maxTokens;

    /** 启用工具（rag/vision/...，逗号分隔） */
    private String toolsConfig;

    /** 当前激活(1)/备用(0)，同 code 至多一个激活 */
    private Boolean isActive;

    /** 状态：0停用 1启用 */
    private Integer status;
}