package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 学生问诊聊天消息请求（PRD 5.2）
 */
@Data
public class ChatMessageDTO {

    @NotBlank(message = "问诊内容不能为空")
    private String message;
}
