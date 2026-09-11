package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentItem;
import com.zhiyu.entity.AssignmentItemProgress;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.ChatMessageLog;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.DailyCaseSchedule;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
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
 *   3. 若传入组合包任务项进度ID，校验进度归属并回填进度 session_id、状态置为问诊中(1)
 *   4. 创建 ChatSession（status=0 进行中），返回 sessionId 供前端建立 SSE 连接
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentSessionServiceImpl implements StudentSessionService {

    private final ChatSessionMapper sessionMapper;
    private final SpCaseConfigMapper caseMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentItemMapper itemMapper;
    private final AssignmentItemProgressMapper progressMapper;
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

        // 2. 校验作业实例/任务项进度（如传）
        Long instanceId = req.getAssignmentInstanceId();
        Long itemProgressId = req.getAssignmentItemProgressId();
        AssignmentInstance inst = null;
        AssignmentItemProgress progress = null;
        if (itemProgressId != null) {
            // 组合包:校验任务项进度归属
            progress = progressMapper.selectById(itemProgressId);
            if (progress == null || !studentId.equals(progress.getStudentId())) {
                throw new BizException(ResultCode.BAD_REQUEST, "任务项进度不存在或不属于当前学生");
            }
            inst = instanceMapper.selectById(progress.getInstanceId());
            if (inst == null) {
                throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
            }
            instanceId = inst.getId();
            AssignmentItem item = itemMapper.selectById(progress.getItemId());
            if (item == null || !"CASE".equals(item.getItemType())) {
                throw new BizException(ResultCode.BAD_REQUEST, "任务项不是病例问诊任务");
            }
            if (!req.getCaseId().equals(progress.getCaseId())) {
                throw new BizException(ResultCode.BAD_REQUEST, "病例ID与任务项不匹配");
            }
            int pStatus = progress.getStatus() == null ? 0 : progress.getStatus();
            if (pStatus >= 2) {
                throw new BizException(ResultCode.BAD_REQUEST, "任务项已进入批阅流程，无法启动问诊");
            }
        } else if (instanceId != null) {
            AssignmentInstance legacyInst = instanceMapper.selectById(instanceId);
            if (legacyInst == null) {
                throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
            }
            if (!studentId.equals(legacyInst.getStudentId())) {
                throw new BizException(ResultCode.FORBIDDEN, "只能启动本人作业实例的问诊");
            }
            if (!req.getCaseId().equals(legacyInst.getCaseId())) {
                throw new BizException(ResultCode.BAD_REQUEST, "病例ID与作业实例不匹配");
            }
            int instStatus = legacyInst.getStatus() == null ? 0 : legacyInst.getStatus();
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

        // 3. 会话复用（会话持久化·2026-09-02）：自主训练/每日一例场景下，若该病例已有
        //    进行中(status=0)会话，直接续聊上次记录——不再每次进入都新建 SP、丢失聊天历史。
        //    作业/组合包实例仍按原逻辑各自建会话（一次作业一个问诊）。
        //    2026-09-03 补丁：历史为空的"僵尸会话"（开场白未落库的旧版本产物/无任何对话）
        //    不再复用——复用它只会看到一片空白，学生误以为聊天记录丢失。置为废弃(3)后
        //    走新建流程，给一个全新 SP 病人 + 重新开场。
        if (instanceId == null && itemProgressId == null) {
            ChatSession ongoing = sessionMapper.selectOne(
                    new LambdaQueryWrapper<ChatSession>()
                            .eq(ChatSession::getStudentId, studentId)
                            .eq(ChatSession::getCaseId, req.getCaseId())
                            .eq(ChatSession::getStatus, 0)
                            .orderByDesc(ChatSession::getId)
                            .last("LIMIT 1"));
            if (ongoing != null) {
                long msgCount = messageMapper.selectCount(
                        new LambdaQueryWrapper<ChatMessageLog>()
                                .eq(ChatMessageLog::getSessionId, ongoing.getId()));
                if (msgCount == 0) {
                    log.info("学生{}的会话{}无任何消息，废弃并新建: caseId={}",
                            studentId, ongoing.getId(), req.getCaseId());
                    ongoing.setStatus(3); // 3=废弃（空会话），不进列表/续聊/评估
                    sessionMapper.updateById(ongoing);
                } else {
                    log.info("学生{}复用进行中会话{}续聊病例{}", studentId, ongoing.getId(), req.getCaseId());
                    return SessionStartVO.builder()
                            .sessionId(ongoing.getId())
                            .studentId(studentId)
                            .caseId(req.getCaseId())
                            .totalExamCost(ongoing.getTotalExamCost() == null
                                    ? BigDecimal.ZERO : ongoing.getTotalExamCost())
                            .status(ongoing.getStatus())
                            .createdAt(ongoing.getCreatedAt())
                            .caseTitle(caseDisplayTitle(c))
                            .department(c.getDepartment())
                            .caseNo(c.getCaseNo())
                            .resumed(true)
                            .build();
                }
            }
        }

        // 4. 创建会话
        ChatSession session = new ChatSession();
        session.setStudentId(studentId);
        session.setCaseId(req.getCaseId());
        session.setAssignmentInstanceId(instanceId);
        session.setAssignmentItemProgressId(itemProgressId);
        session.setTotalExamCost(BigDecimal.ZERO);
        session.setStatus(0); // 进行中
        sessionMapper.insert(session);

        // 4b. 回填进度/实例 session_id 与状态
        if (progress != null) {
            progress.setSessionId(session.getId());
            progress.setStatus(1); // 问诊中
            progressMapper.updateById(progress);
            if (inst != null) {
                inst.setStatus(1); // 问诊中
                instanceMapper.updateById(inst);
            }
        } else if (instanceId != null) {
            AssignmentInstance upd = new AssignmentInstance();
            upd.setId(instanceId);
            upd.setSessionId(session.getId());
            upd.setStatus(1); // 问诊中
            instanceMapper.updateById(upd);
        }

        log.info("学生{}启动问诊会话{}，caseId={} instanceId={} itemProgressId={}",
                studentId, session.getId(), req.getCaseId(), instanceId, itemProgressId);

        // 5. SP 主动开场（PRD 5.2 优化）：AI 不可用降级为占位文案，不阻断 start 主流程
        String openingMessage;
        boolean openingDegraded;
        try {
            String raw = aiPlatformClient.chatOpening(session.getId(), studentId, req.getCaseId());
            openingMessage = raw;
            openingDegraded = (raw == null || raw.isBlank());
            if (openingDegraded) openingMessage = "医生您好，我最近一直不太舒服，想来找您看看。";
        } catch (Exception e) {
            log.warn("SP 开场白生成失败，使用兜底文案: sessionId={} err={}",
                    session.getId(), e.getMessage());
            openingMessage = "医生您好，我最近一直不太舒服，想来找您看看。";
            openingDegraded = true;
        }

        // 5b. 开场白落库（2026-09-03）：开场白此前只透传移动端、不写 ChatMessageLog，
        //     导致续聊时历史里永远没有开场白、甚至整段历史为空被当成"记录丢失"。
        //     学生实际看到什么就存什么（含降级文案），保证会话记录完整可复盘。
        try {
            ChatMessageLog openingLog = new ChatMessageLog();
            openingLog.setSessionId(session.getId());
            openingLog.setSender("SP");
            openingLog.setContent(openingMessage);
            messageMapper.insert(openingLog);
        } catch (Exception e) {
            log.warn("开场白落库失败（不影响会话启动）: sessionId={} err={}",
                    session.getId(), e.getMessage());
        }

        return SessionStartVO.builder()
                .sessionId(session.getId())
                .studentId(studentId)
                .caseId(req.getCaseId())
                .assignmentInstanceId(instanceId)
                .assignmentItemProgressId(itemProgressId)
                .totalExamCost(BigDecimal.ZERO)
                .status(0)
                .createdAt(session.getCreatedAt())
                .openingMessage(openingMessage)
                .openingDegraded(openingDegraded)
                .caseTitle(caseDisplayTitle(c))
                .department(c.getDepartment())
                .caseNo(c.getCaseNo())
                .resumed(false)
                .build();
    }

    /** 问诊室展示标题：科室+病号（如「心血管内科 · No.213」）；不暴露具体病名防剧透。 */
    private String caseDisplayTitle(SpCaseConfig c) {
        String department = c.getDepartment() == null ? "" : c.getDepartment().trim();
        String no = c.getCaseNo() == null ? "" : c.getCaseNo().trim();
        StringBuilder sb = new StringBuilder();
        if (!department.isEmpty()) {
            sb.append(department);
        } else {
            sb.append("SP 问诊");
        }
        if (!no.isEmpty()) {
            sb.append(" · No.").append(no);
        }
        return sb.toString();
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
                aiPlatformClient.evaluateAndArchiveSession(sessionId, studentId);
                log.info("AI评估与归档成功: sessionId={} studentId={}", sessionId, studentId);
            } catch (Exception e) {
                // 会话已经结束，但评估归档是独立的可重试步骤；记录异常状态，
                // 让学生/管理端知道结果尚未生成，而不是把失败隐藏在日志里。
                session.setStatus(2);
                sessionMapper.updateById(session);
                log.warn("AI评估与归档失败，标记会话待重试: sessionId={} studentId={} error={}",
                        sessionId, studentId, e.getMessage());
            }
        }
    }

    @Override
    public void retryArchive(Long sessionId) {
        Long studentId = UserContext.requireUserId();
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        if (!studentId.equals(session.getStudentId())) throw new BizException(ResultCode.FORBIDDEN);
        if (!Integer.valueOf(2).equals(session.getStatus())) {
            throw new BizException(ResultCode.BAD_REQUEST, "当前会话不需要重试评估");
        }
        try {
            aiPlatformClient.evaluateAndArchiveSession(sessionId, studentId);
            session.setStatus(1);
            sessionMapper.updateById(session);
            log.info("AI评估归档重试成功: sessionId={} studentId={}", sessionId, studentId);
        } catch (Exception e) {
            log.warn("AI评估归档重试失败: sessionId={} studentId={} error={}",
                    sessionId, studentId, e.getMessage());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI评估仍未完成，请稍后重试");
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
    public ChatSession requireSessionForStudent(Long sessionId, Long studentId) {
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) {
            throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        }
        if (studentId == null || !studentId.equals(session.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN, "问诊会话不属于当前学生");
        }
        return session;
    }

    @Override
    public Map<String, Object> mentor(Long sessionId) {
        Long studentId = UserContext.requireUserId();
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) {
            throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        }
        if (!studentId.equals(session.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN, "问诊会话不属于当前学生");
        }
        if (!Integer.valueOf(0).equals(session.getStatus())) {
            throw new BizException(ResultCode.BAD_REQUEST, "问诊会话已结束");
        }
        return aiPlatformClient.sessionMentor(session.getId(), studentId, session.getCaseId());
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
            result.put("status", "DEGRADED");
            result.put("source", "NONE");
            result.put("degraded", true);
            return result;
        }
        // 键名归一：AI 侧契约是 snake_case（safety_blocked / citations），移动端读
        // camelCase（safetyBlocked）。此前仅降级分支写了 safetyBlocked，正常读图结果
        // 原样透传 → 移动端 `res['safetyBlocked'] == true` 永远不成立，「影像触发
        // 安全策略」的提示从不显示（2026-09-11 修复）。
        Map<String, Object> normalized = new java.util.LinkedHashMap<>(result);
        if (normalized.get("safetyBlocked") == null && normalized.get("safety_blocked") != null) {
            normalized.put("safetyBlocked", normalized.get("safety_blocked"));
        }
        normalized.putIfAbsent("safetyBlocked", false);
        return normalized;
    }
}
