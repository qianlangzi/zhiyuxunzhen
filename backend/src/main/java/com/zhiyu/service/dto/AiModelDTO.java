package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.math.BigDecimal;

/**
 * AI 模型新增/更新请求（模型管理）
 *
 * 更新时 apiKey 传空串表示「保留原密钥」——前端回显的是脱敏值，
 * 仅在管理员重新输入真实密钥时才回传，避免脱敏值覆盖真实密钥。
 */
@Data
public class AiModelDTO {

    @NotBlank(message = "模型名称不能为空")
    private String name;

    /** 供应商/来源说明 */
    private String provider;

    @NotBlank(message = "能力类型不能为空")
    private String capability;

    @NotBlank(message = "接口地址不能为空")
    private String baseUrl;

    /** API 密钥（更新时为空=保留原值） */
    private String apiKey;

    @NotBlank(message = "模型名不能为空")
    private String model;

    /** 向量维度 */
    private Integer dimension;

    /** 请求超时（秒） */
    private Integer timeoutSeconds;

    /** 最大生成 tokens */
    private Integer maxTokens;

    /** 温度 */
    private BigDecimal temperature;

    /** 状态：0停用 1启用 */
    private Integer status;

    /** 备注 */
    private String description;
}