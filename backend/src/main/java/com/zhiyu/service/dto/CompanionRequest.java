package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * 学生 AI 学伴对话请求（P1-2，学习陪伴）
 * 学生与学伴闲聊 + 策略建议；Spring Boot 组装学生学情上下文后转发 AI 中台。
 */
@Data
public class CompanionRequest {

    /** 学生当前输入（闲聊/困惑/请求建议） */
    @NotBlank(message = "消息不能为空")
    @Size(max = 2000, message = "消息长度不能超过2000字")
    private String message;

    /** 可选图片地址（支持 HTTP(S) URL 或 base64 data URL），与 message 一起作为用户消息；为空则纯文本 */
    private String imageUrl;

    /** 多轮对话历史 [{role: user|assistant, content}]，支持追问与指代消解 */
    private List<Map<String, String>> history;

    /** 可选：当前学伴会话 ID（companion_conversation.id）。转发 AI 作为 session_id，
     *  供对话后记忆抽取回填 source_session_id（来源溯源）；非本人会话将被忽略。 */
    private Long conversationId;
}
