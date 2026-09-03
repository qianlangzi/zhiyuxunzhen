package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 重命名 AI 学伴会话请求（P1-2 会话历史管理）
 */
@Data
public class CompanionConversationRenameRequest {

    /** 会话标题 */
    @NotBlank(message = "会话标题不能为空")
    @Size(max = 100, message = "会话标题长度不能超过100字")
    private String title;
}