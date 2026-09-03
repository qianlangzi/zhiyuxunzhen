package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.CompanionConversation;
import com.zhiyu.entity.CompanionMessage;
import com.zhiyu.mapper.CompanionConversationMapper;
import com.zhiyu.mapper.CompanionMessageMapper;
import com.zhiyu.service.CompanionConversationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * AI 学伴会话服务实现（P1-2 会话历史管理）
 */
@Service
@RequiredArgsConstructor
public class CompanionConversationServiceImpl implements CompanionConversationService {

    private final CompanionConversationMapper conversationMapper;
    private final CompanionMessageMapper messageMapper;

    @Override
    public PageResult<CompanionConversation> list(int pageNum, int pageSize) {
        Long studentId = UserContext.requireUserId();
        Page<CompanionConversation> page = new Page<>(pageNum, pageSize);
        conversationMapper.selectPage(page, new LambdaQueryWrapper<CompanionConversation>()
                .eq(CompanionConversation::getStudentId, studentId)
                .eq(CompanionConversation::getDeleted, 0)
                .orderByDesc(CompanionConversation::getCreatedAt)
                .orderByDesc(CompanionConversation::getId));
        return PageResult.of(page);
    }

    @Override
    public CompanionConversation create(String title) {
        Long studentId = UserContext.requireUserId();
        CompanionConversation c = new CompanionConversation();
        c.setStudentId(studentId);
        c.setTitle(StringUtils.hasText(title) ? title : "新对话");
        c.setDeleted(0);
        conversationMapper.insert(c);
        return c;
    }

    @Override
    public CompanionConversation rename(Long id, String title) {
        CompanionConversation c = requireOwned(id);
        c.setTitle(StringUtils.hasText(title) ? title : "新对话");
        conversationMapper.updateById(c);
        return c;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        CompanionConversation c = requireOwned(id);
        c.setDeleted(1);
        conversationMapper.updateById(c);
    }

    @Override
    public PageResult<CompanionMessage> listMessages(Long conversationId, int pageNum, int pageSize) {
        requireOwned(conversationId);
        Page<CompanionMessage> page = new Page<>(pageNum, pageSize);
        messageMapper.selectPage(page, new LambdaQueryWrapper<CompanionMessage>()
                .eq(CompanionMessage::getConversationId, conversationId)
                .orderByAsc(CompanionMessage::getId));
        return PageResult.of(page);
    }

    @Override
    public CompanionMessage addMessage(Long conversationId, String sender, String content, String imageUrl) {
        requireOwned(conversationId);
        CompanionMessage m = new CompanionMessage();
        m.setConversationId(conversationId);
        m.setSender("assistant".equals(sender) ? "assistant" : "user");
        m.setContent(content);
        m.setImageUrl(StringUtils.hasText(imageUrl) ? imageUrl : null);
        messageMapper.insert(m);
        return m;
    }

    @Override
    public boolean isOwned(Long conversationId) {
        if (conversationId == null) {
            return false;
        }
        Long studentId = UserContext.requireUserId();
        CompanionConversation c = conversationMapper.selectById(conversationId);
        return c != null && studentId.equals(c.getStudentId())
                && !Integer.valueOf(1).equals(c.getDeleted());
    }

    /** 校验会话归属当前学生，返回有效会话；否则 1404 */
    private CompanionConversation requireOwned(Long id) {
        if (id == null) {
            throw new BizException(ResultCode.NOT_FOUND, "会话不存在");
        }
        Long studentId = UserContext.requireUserId();
        CompanionConversation c = conversationMapper.selectById(id);
        if (c == null || !studentId.equals(c.getStudentId()) || Integer.valueOf(1).equals(c.getDeleted())) {
            throw new BizException(ResultCode.NOT_FOUND, "会话不存在");
        }
        return c;
    }
}