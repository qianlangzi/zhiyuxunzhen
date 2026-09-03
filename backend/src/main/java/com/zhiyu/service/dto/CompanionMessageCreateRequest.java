package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 写入 AI 学伴消息请求（P1-2 会话历史管理）
 */
@Data
public class CompanionMessageCreateRequest {

    /** 发送方 user/assistant（缺省为 user） */
    @Pattern(regexp = "user|assistant", message = "sender 仅支持 user/assistant")
    private String sender;

    /** 文本内容 */
    @NotBlank(message = "消息内容不能为空")
    @Size(max = 2000, message = "消息长度不能超过2000字")
    private String content;

    /** 图片(HTTP URL 或 data URL)，可空 */
    @Size(max = 20000, message = "图片数据过大")
    private String imageUrl;
}