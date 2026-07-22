package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.ChatMessageLog;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.ChatMessageLogMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.AiSessionContextService;
import com.zhiyu.service.dto.internal.SessionMessageAppendDTO;
import com.zhiyu.vo.AiSessionContextVO;
import com.zhiyu.vo.AiReportContextVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class AiSessionContextServiceImpl implements AiSessionContextService {

    private static final Set<String> ALLOWED_SENDERS = Set.of("STUDENT", "SP", "MENTOR", "SYSTEM");

    private final ChatSessionMapper sessionMapper;
    private final ChatMessageLogMapper messageMapper;
    private final SpCaseConfigMapper caseMapper;

    @Override
    public AiSessionContextVO getContext(Long sessionId, Long studentId) {
        ChatSession session = requireOwnedSession(sessionId, studentId);
        SpCaseConfig c = caseMapper.selectById(session.getCaseId());
        if (c == null) throw new BizException(ResultCode.CASE_NOT_FOUND);
        List<AiSessionContextVO.Message> messages = messageMapper.selectList(
                        new LambdaQueryWrapper<ChatMessageLog>()
                                .eq(ChatMessageLog::getSessionId, sessionId)
                                .orderByAsc(ChatMessageLog::getCreatedAt))
                .stream()
                .map(item -> AiSessionContextVO.Message.builder()
                        .sender(item.getSender())
                        .content(item.getContent())
                        .citations(item.getCitations())
                        .build())
                .toList();
        return AiSessionContextVO.builder()
                .sessionId(session.getId())
                .studentId(session.getStudentId())
                .caseId(session.getCaseId())
                .title(c.getTitle())
                .patientProfile(c.getPatientProfile())
                .hiddenDisease(c.getHiddenDisease())
                .standardPathJson(c.getStandardPathJson())
                .presetExams(c.getPresetExams())
                .messages(messages)
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void appendMessages(Long sessionId, SessionMessageAppendDTO dto) {
        requireOwnedSession(sessionId, dto.getStudentId());
        for (SessionMessageAppendDTO.MessageItem item : dto.getMessages()) {
            String sender = item.getSender().trim().toUpperCase();
            if (!ALLOWED_SENDERS.contains(sender)) {
                throw new BizException(ResultCode.BAD_REQUEST, "不支持的消息发送者: " + sender);
            }
            ChatMessageLog log = new ChatMessageLog();
            log.setSessionId(sessionId);
            log.setSender(sender);
            log.setContent(item.getContent());
            log.setCitations(item.getCitations());
            messageMapper.insert(log);
        }
    }

    @Override
    public AiReportContextVO getReportContext(Long sessionId) {
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        SpCaseConfig c = caseMapper.selectById(session.getCaseId());
        if (c == null) throw new BizException(ResultCode.CASE_NOT_FOUND);
        List<AiSessionContextVO.Message> messages = messageMapper.selectList(
                        new LambdaQueryWrapper<ChatMessageLog>()
                                .eq(ChatMessageLog::getSessionId, sessionId)
                                .orderByAsc(ChatMessageLog::getCreatedAt))
                .stream()
                .map(item -> AiSessionContextVO.Message.builder()
                        .sender(item.getSender())
                        .content(item.getContent())
                        .citations(item.getCitations())
                        .build())
                .toList();
        return AiReportContextVO.builder()
                .sessionId(session.getId())
                .studentId(session.getStudentId())
                .caseId(session.getCaseId())
                .caseTitle(c.getTitle())
                .status(session.getStatus())
                .osceScoreJson(session.getOsceScoreJson())
                .finalReport(session.getFinalReport())
                .totalExamCost(session.getTotalExamCost())
                .messages(messages)
                .build();
    }

    private ChatSession requireOwnedSession(Long sessionId, Long studentId) {
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        if (!session.getStudentId().equals(studentId)) {
            throw new BizException(ResultCode.FORBIDDEN, "问诊会话不属于当前学生");
        }
        if (session.getStatus() == null || session.getStatus() != 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "问诊会话已结束");
        }
        return session;
    }
}
