package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * AI 学伴消息（P1-2 会话历史管理）
 * 单条对话记录：user/assistant + 可选图片（HTTP URL 或 data URL）。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("companion_message")
public class CompanionMessage extends BaseEntity {

    /** 会话ID */
    private Long conversationId;

    /** 发送方 user/assistant */
    private String sender;

    /** 文本内容 */
    private String content;

    /** 图片(HTTP URL 或 data URL) */
    private String imageUrl;
}