package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * AI RAG 热运行参数（AI 配置中心 · 检索/改写/迭代/图述 等键值热改）
 *
 * config_key 与 AI 中台运行参数对齐（如 citation_max_chars、query_rewrite_enabled）。
 * AI 中台周期热拉取后覆盖运行期值，立即生效。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("ai_runtime_config")
public class AiRuntimeConfig extends BaseEntity {

    /** 配置键 */
    private String configKey;

    /** 显示名称 */
    private String configName;

    /** 说明 */
    private String description;

    /** 类型：number/switch/float/text */
    private String configType;

    /** 当前生效值 */
    private String value;

    /** 默认值（重置用） */
    private String defaultValue;

    /** 最小值（number/float 用） */
    private String min;

    /** 最大值（number/float 用） */
    private String max;

    /** 步长（number/float 用） */
    private String step;

    /** 是否参与下发(1)/冻结(0) */
    private Boolean isActive;
}