package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.math.BigDecimal;

/**
 * AI Agent 元参数新增/更新请求（Agent 管理）
 */
@Data
public class AiAgentDTO {

    @NotBlank(message = "Agent 逻辑键不能为空")
    private String code;

    @NotBlank(message = "显示名称不能为空")
    private String name;

    /** 职责说明 */
    private String description;

    /** 引用的提示词逻辑键 */
    private String promptName;

    /** system prompt 直接覆盖文本 */
    private String promptOverride;

    /** 采样温度覆盖 */
    private BigDecimal temperature;

    /** 最大生成 tokens 覆盖 */
    private Integer maxTokens;

    /** 启用工具（rag/vision/...） */
    private String toolsConfig;

    /** 状态：0停用 1启用 */
    private Integer status;
}