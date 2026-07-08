package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 对话明细表（PRD 8.7）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("chat_message_log")
public class ChatMessageLog extends BaseEntity {

    private Long sessionId;

    /** STUDENT / SP / MENTOR / SYSTEM */
    private String sender;

    private String content;

    private String multimodalUrl;

    /** 圈选坐标 JSON */
    private String annotationJson;

    /** RAG 溯源 JSON */
    private String citations;
}
