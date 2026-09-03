package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * AI RAG 运行参数新增/更新请求（RAG 管理）
 */
@Data
public class AiRuntimeConfigDTO {

    @NotBlank(message = "配置键不能为空")
    private String configKey;

    @NotBlank(message = "显示名称不能为空")
    private String configName;

    /** 说明 */
    private String description;

    /** 类型：number/switch/float/text */
    private String configType;

    @NotBlank(message = "配置值不能为空")
    private String value;

    /** 默认值 */
    private String defaultValue;

    /** 最小值 */
    private String min;

    /** 最大值 */
    private String max;

    /** 步长 */
    private String step;
}