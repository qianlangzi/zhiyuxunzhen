package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.ChatMessageLog;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.DailyCaseSchedule;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.ChatMessageLogMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.DailyCaseScheduleMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.service.StudentSessionService;
import com.zhiyu.service.dto.SessionStartDTO;
import com.zhiyu.vo.SessionStartVO;
import com.zhiyu.vo.StudentSessionDetailVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.time.LocalDateTime;
import java.time.LocalDate;

/**
 * 学生问诊会话服务实现（PRD 5.2 第 1 步）
 * 学生选择病例进入问诊室：
 *   1. 校验病例存在且未删除
 *   2. 若传入作业实例ID，校验实例归属当前学生且病例匹配，并将实例状态置为"问诊中(1)"、回填 session_id
 *   3. 创建 ChatSession（status=0 进行中），返回 sessionId 供前端建立 SSE 连接
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentSessionServiceImpl implements StudentSessionService {

    private final ChatSessionMapper sessionMapper;
    private final SpCaseConfigMapper caseMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final ChatMessageLogMapper messageMapper;
    private final DailyCaseScheduleMapper dailyCaseScheduleMapper;
    private final AiPlatformClient aiPlatformClient;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public SessionStartVO start(SessionStartDTO req) {
        Long studentId = UserContext.requireUserId();

        // 1. 校验病例
        SpCaseConfig c = caseMapper.selectById(req.getCaseId());
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }

        // 2. 校验作业实例（如传）
        Long instanceId = req.getAssignmentInstanceId();
        if (instanceId != null) {
            AssignmentInstance inst = instanceMapper.selectById(instanceId);
            if (inst == null) {
                throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
            }
            if (!studentId.equals(inst.getStudentId())) {
                throw new BizException(ResultCode.FORBIDDEN, "只能启动本人作业实例的问诊");
            }
            if (!req.getCaseId().equals(inst.getCaseId())) {
                throw new BizException(ResultCode.BAD_REQUEST, "病例ID与作业实例不匹配");
            }
            int instStatus = inst.getStatus() == null ? 0 : inst.getStatus();
            // 已提交大病历(2/3/4/5)不允许再启动问诊
            if (instStatus >= 2) {
                throw new BizException(ResultCode.BAD_REQUEST, "作业实例已进入批阅流程，无法启动问诊");
            }
        } else {
            boolean publicCase = Boolean.TRUE.equals(c.getIsPublic())
                    && Integer.valueOf(2).equals(c.getAdminAuditStatus())
                    && Integer.valueOf(1).equals(c.getStatus());
            boolean todayDailyCase = dailyCaseScheduleMapper.selectCount(
                    new LambdaQueryWrapper<DailyCaseSchedule>()
                            .eq(DailyCaseSchedule::getCaseId, req.getCaseId())
                            .eq(DailyCaseSchedule::getPublishDate, LocalDate.now())
                            .eq(DailyCaseSchedule::getStatus, 2)) > 0;
            if (!publicCase && !todayDailyCase) {
                throw new BizException(ResultCode.FORBIDDEN, "该病例未公开且未分配给当前学生");
            }
        }

        // 3. 创建会话
        ChatSession session = new ChatSession();
        session.setStudentId(studentId);
        session.setCaseId(req.getCaseId());
        session.setAssignmentInstanceId(instanceId);
        session.setTotalExamCost(BigDecimal.ZERO);
        session.setStatus(0); // 进行中
        sessionMapper.insert(session);

        // 4. 回填实例 session_id 与状态
        if (instanceId != null) {
            AssignmentInstance upd = new AssignmentInstance();
            upd.setId(instanceId);
            upd.setSessionId(session.getId());
            upd.setStatus(1); // 问诊中
            instanceMapper.updateById(upd);
        }

        log.info("学生{}启动问诊会话{}，caseId={} instanceId={}",
                studentId, session.getId(), req.getCaseId(), instanceId);

        return SessionStartVO.builder()
                .sessionId(session.getId())
                .studentId(studentId)
                .caseId(req.getCaseId())
                .assignmentInstanceId(instanceId)
                .totalExamCost(BigDecimal.ZERO)
                .status(0)
                .createdAt(session.getCreatedAt())
                .build();
    }

    @Override
    public StudentSessionDetailVO detail(Long sessionId) {
        Long studentId = UserContext.requireUserId();
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) {
            throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        }
        if (!studentId.equals(session.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN, "问诊会话不属于当前学生");
        }
        List<StudentSessionDetailVO.Message> messages = messageMapper.selectList(
                        new LambdaQueryWrapper<ChatMessageLog>()
                                .eq(ChatMessageLog::getSessionId, sessionId)
                                .orderByAsc(ChatMessageLog::getCreatedAt))
                .stream()
                .map(item -> StudentSessionDetailVO.Message.builder()
                        .sender(item.getSender())
                        .content(item.getContent())
                        .createdAt(item.getCreatedAt())
                        .build())
                .toList();
        return StudentSessionDetailVO.builder()
                .sessionId(session.getId())
                .caseId(session.getCaseId())
                .status(session.getStatus())
                .createdAt(session.getCreatedAt())
                .messages(messages)
                .build();
    }

    @Override
    public void finish(Long sessionId) {
        Long studentId = UserContext.requireUserId();
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        if (!studentId.equals(session.getStudentId())) throw new BizException(ResultCode.FORBIDDEN);
        if (Integer.valueOf(0).equals(session.getStatus())) {
            session.setStatus(1);
            session.setEndedAt(LocalDateTime.now());
            sessionMapper.updateById(session);

            // 异步调用 AI 中台评估与归档，失败不影响会话状态变更
            try {
                String resp = aiPlatformClient.evaluateAndArchiveSession(sessionId, studentId);
                log.info("AI评估与归档成功: sessionId={} studentId={} resp={}", sessionId, studentId, resp);
            } catch (Exception e) {
                log.warn("AI评估与归档调用失败，不影响会话关闭: sessionId={} studentId={} error={}",
                        sessionId, studentId, e.getMessage());
            }
        }
    }

    @Override
    public Map<String, Object> chat(Long sessionId, String message) {
        Long studentId = UserContext.requireUserId();
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) {
            throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        }
        if (!studentId.equals(session.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN, "问诊会话不属于当前学生");
        }
        if (!Integer.valueOf(0).equals(session.getStatus())) {
            throw new BizException(ResultCode.BAD_REQUEST, "问诊会话已结束，无法继续发送消息");
        }
        return aiPlatformClient.chatSync(session.getId(), studentId, session.getCaseId(), message);
    }

    @Override
    public Map<String, Object> analyzeImage(Long sessionId, String imageUrl,
                                            List<Double> imageBbox, String studentNote,
                                            String mobileToken) {
        Long studentId = UserContext.requireUserId();
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) {
            throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        }
        if (!studentId.equals(session.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN, "问诊会话不属于当前学生");
        }
        Map<String, Object> result = aiPlatformClient.analyzeVision(
                sessionId, studentId, imageUrl, imageBbox, studentNote, mobileToken);
        if (result == null) {
            // AI 未配置或调用失败：返回本地降级反馈，保证多模态闭环可用
            result = new java.util.HashMap<>();
            result.put("finding", "读图服务暂不可用，请稍后重试。");
            result.put("safetyBlocked", false);
        }
        return result;
    }
}
