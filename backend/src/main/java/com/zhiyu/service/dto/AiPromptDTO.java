package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * AI 提示词新增/更新请求（提示词管理）
 */
@Data
public class AiPromptDTO {

    @NotBlank(message = "提示词逻辑键不能为空")
    private String name;

    /** 版本号 */
    private String version;

    @NotBlank(message = "显示名称不能为空")
    private String title;

    /** 用途说明 */
    private String description;

    @NotBlank(message = "提示词正文不能为空")
    private String content;

    /** 状态：0停用 1启用 */
    private Integer status;
}