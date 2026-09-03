package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * AI 提示词管理（AI 配置中心 · 提示词热改）
 *
 * 存储各 Agent 的 system prompt。name 为逻辑键，同一 name 可有多个版本，
 * 同一 name 下至多一个 is_active=1；AI 中台周期热拉取「启用且激活」的最新值。
 * content 支持 {占位符} 插入运行时变量；未配置的 name 由 AI 中台回退内置模板。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("ai_prompt")
public class AiPrompt extends BaseEntity {

    /** 提示词逻辑键（与 AI 中台内置模板名对齐） */
    private String name;

    /** 版本号（如 v1/v2） */
    private String version;

    /** 显示名称 */
    private String title;

    /** 用途说明 */
    private String description;

    /** 提示词正文（支持 {占位符}） */
    private String content;

    /** 当前激活(1)/备用(0)，同 name 至多一个激活 */
    private Boolean isActive;

    /** 状态：0停用 1启用 */
    private Integer status;
}