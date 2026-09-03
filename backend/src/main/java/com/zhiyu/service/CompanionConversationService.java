package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.CompanionConversation;
import com.zhiyu.entity.CompanionMessage;

/**
 * AI 学伴会话服务（P1-2 会话历史管理）
 * 会话 CRUD + 消息读写；归属校验均以当前登录学生为准。
 */
public interface CompanionConversationService {

    /** 当前学生会话列表（分页，倒序） */
    PageResult<CompanionConversation> list(int pageNum, int pageSize);

    /** 新建会话 */
    CompanionConversation create(String title);

    /** 重命名会话（仅本人） */
    CompanionConversation rename(Long id, String title);

    /** 逻辑删除会话（仅本人） */
    void delete(Long id);

    /** 会话消息分页列表（仅本人） */
    PageResult<CompanionMessage> listMessages(Long conversationId, int pageNum, int pageSize);

    /** 写入会话消息（仅本人） */
    CompanionMessage addMessage(Long conversationId, String sender, String content, String imageUrl);

    /**
     * 会话是否属于当前登录学生。
     * 学伴对话转发 AI 前校验 conversationId 归属，防止伪造 id 污染记忆来源标注。
     */
    boolean isOwned(Long conversationId);
}