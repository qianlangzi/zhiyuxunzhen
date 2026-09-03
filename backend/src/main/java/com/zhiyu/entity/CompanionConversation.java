package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * AI 学伴会话（P1-2 会话历史管理）
 * 与 chat_session（问诊会话）解耦：学伴=陪伴闲聊，不承载评分/病例字段。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("companion_conversation")
public class CompanionConversation extends BaseEntity {

    /** 学生ID */
    private Long studentId;

    /** 会话标题（首条消息截断） */
    private String title;

    /** 逻辑删除 0否 1是 */
    private Integer deleted;
}