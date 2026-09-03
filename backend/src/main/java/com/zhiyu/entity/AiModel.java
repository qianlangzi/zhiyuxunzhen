package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

/**
 * AI 模型供应商配置（PRD 4.16 扩展 · 模型管理）
 *
 * 参照 ccswitch 供应商管理模式：同一能力维度可配置多个供应商模型，
 * 通过 is_active 标记当前激活项，管理端可一键切换即时生效（AI 中台热读取）。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("ai_model")
public class AiModel extends BaseEntity {

    /** 模型显示名称 */
    private String name;

    /** 供应商/来源说明 */
    private String provider;

    /** 能力类型：LLM / VISION / EMBEDDING / EMBEDDING_MULTI */
    private String capability;

    /** OpenAI 兼容接口地址 */
    private String baseUrl;

    /** API 密钥（明文存库，返回给前端时脱敏） */
    private String apiKey;

    /** 实际模型名 */
    private String model;

    /** 向量维度（EMBEDDING 系用） */
    private Integer dimension;

    /** 请求超时（秒） */
    private Integer timeoutSeconds;

    /** 最大生成 tokens */
    private Integer maxTokens;

    /** 温度 */
    private BigDecimal temperature;

    /** 当前激活(1)/备用(0)，每能力至多一个激活 */
    private Boolean isActive;

    /** 状态：0停用 1启用 */
    private Integer status;

    /** 备注 */
    private String description;

    @TableField(exist = false)
    private static final long serialVersionUID = 1L;
}