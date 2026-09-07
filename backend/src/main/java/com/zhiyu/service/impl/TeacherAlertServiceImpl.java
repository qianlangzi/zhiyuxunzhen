package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.*;
import com.zhiyu.mapper.*;
import com.zhiyu.service.TeacherAlertService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 学情预警服务实现（Rule-first 规则引擎）
 *
 * 规则：
 * 1. osce_low（高）：最近 5 次已完成会话中，连续 3 次总分 < 60 或任一单维 < 50
 * 2. assignment_overdue（中）：累计 >= 2 个已过期未交作业
 * 3. daily_break（中）：近 7 天每日一例完成 < 3 次
 * 4. weakness_worsening（高）：掌握度 < 0.6 且证据计数 >= 3（持续薄弱）
 * 5. behavior_abnormal（低）：最近会话消息过少(<3)即提交诊断 或 过多(>30)
 *
 * AI 只负责干预建议生成（/insight/alert），触发判定全部确定性计算。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherAlertServiceImpl implements TeacherAlertService {

    private final ChatSessionMapper chatSessionMapper;
    private final ChatMessageLogMapper messageLogMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentMapper assignmentMapper;
    private final DailyCaseSubmissionMapper dailyCaseMapper;
    private final StudentWeaknessMapper weaknessMapper;
    private final StudentAlertMapper alertMapper;
    private final SysNotificationMapper notificationMapper;
    private final SysUserMapper userMapper;
    private final StudentClassMembershipMapper membershipMapper;
    private final TeachingClassMapper classMapper;
    private final TeacherClassAuthorizationMapper authorizationMapper;
    private final AiPlatformClient aiPlatformClient;
    private final ObjectMapper objectMapper;

    private static final int OSCE_LOW_THRESHOLD = 60;
    private static final double DIM_LOW_THRESHOLD = 50;
    private static final int OVERDUE_COUNT = 2;
    private static final double WEAKNESS_THRESHOLD = 0.6;
    private static final int WEAKNESS_EVIDENCE = 3;

    // ---------------- 规则引擎 ----------------

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void scan() {
        Long teacherId = UserContext.requireUserId();
        // 本教师授权班级内的学生
        List<Long> classIds = authorizationMapper.selectList(
                        new LambdaQueryWrapper<TeacherClassAuthorization>()
                                .eq(TeacherClassAuthorization::getTeacherId, teacherId))
                .stream().map(TeacherClassAuthorization::getClassId).toList();
        if (classIds.isEmpty()) return;

        Set<Long> studentIds = new LinkedHashSet<>();
        for (Long classId : classIds) {
            membershipMapper.selectList(new LambdaQueryWrapper<StudentClassMembership>()
                            .eq(StudentClassMembership::getClassId, classId))
                    .forEach(m -> studentIds.add(m.getStudentId()));
        }
        // 兜底并集 sys_user.class_id 遗留学生
        userMapper.selectList(new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 0)
                        .eq(SysUser::getStatus, 0)
                        .in(SysUser::getClassId, classIds))
                .forEach(u -> studentIds.add(u.getId()));
        List<SysUser> students = studentIds.isEmpty() ? List.of()
                : userMapper.selectList(new LambdaQueryWrapper<SysUser>()
                        .in(SysUser::getId, studentIds)
                        .eq(SysUser::getRole, 0)
                        .eq(SysUser::getStatus, 0));

        for (SysUser student : students) {
            scanStudent(student, teacherId, classIds);
        }
        log.info("教师{}学情预警扫描完成，覆盖学生{}人", teacherId, students.size());
    }

    private void scanStudent(SysUser student, Long teacherId, List<Long> classIds) {
        Long sid = student.getId();
        List<StudentAlert> fired = new ArrayList<>();

        // 规则1：OSCE 连续低分（高）
        List<ChatSession> sessions = chatSessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>()
                        .eq(ChatSession::getStudentId, sid)
                        .eq(ChatSession::getStatus, 1)
                        .orderByDesc(ChatSession::getEndedAt)
                        .last("LIMIT 5"));
        int lowStreak = 0;
        Map<String, Object> osceDetail = new HashMap<>();
        for (ChatSession s : sessions) {
            double total = parseOsceTotal(s.getOsceScoreJson());
            if (total > 0 && (total < OSCE_LOW_THRESHOLD || hasLowDimension(s.getOsceScoreJson()))) {
                lowStreak++;
            } else {
                lowStreak = 0;
            }
        }
        if (lowStreak >= 3) {
            osceDetail.put("consecutiveLow", lowStreak);
            osceDetail.put("recentSessions", sessions.size());
            fired.add(buildAlert(sid, student.getClassId(), "osce_low", 3, osceDetail, teacherId));
        }

        // 规则2：作业逾期（中）
        List<AssignmentInstance> instances = instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>()
                        .eq(AssignmentInstance::getStudentId, sid)
                        .in(AssignmentInstance::getStatus, 0, 1)); // 未开始/问诊中
        long overdue = instances.stream()
                .filter(i -> {
                    Assignment a = assignmentMapper.selectById(i.getAssignmentId());
                    return a != null && a.getDeadline() != null && a.getDeadline().isBefore(LocalDateTime.now());
                }).count();
        if (overdue >= OVERDUE_COUNT) {
            fired.add(buildAlert(sid, student.getClassId(), "assignment_overdue", 2,
                    Map.of("overdueCount", overdue, "threshold", OVERDUE_COUNT), teacherId));
        }

        // 规则3：每日一例断档（中）
        LocalDateTime weekAgo = LocalDateTime.now().minusDays(7);
        long dailyCount = dailyCaseMapper.selectCount(
                new LambdaQueryWrapper<DailyCaseSubmission>()
                        .eq(DailyCaseSubmission::getStudentId, sid)
                        .ge(DailyCaseSubmission::getSubmittedAt, weekAgo));
        if (dailyCount < 3) {
            fired.add(buildAlert(sid, student.getClassId(), "daily_break", 2,
                    Map.of("last7DaysCompleted", dailyCount, "threshold", 3), teacherId));
        }

        // 规则4：薄弱点恶化（高）
        List<StudentWeakness> weaknesses = weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, sid)
                        .lt(StudentWeakness::getWeaknessScore, WEAKNESS_THRESHOLD)
                        .ge(StudentWeakness::getEvidenceCount, WEAKNESS_EVIDENCE)
                        .orderByAsc(StudentWeakness::getWeaknessScore)
                        .last("LIMIT 5"));
        if (!weaknesses.isEmpty()) {
            List<Map<String, Object>> weakInfo = weaknesses.stream().map(w -> {
                Map<String, Object> m = new HashMap<>();
                m.put("knowledgeTag", w.getKnowledgeTag());
                m.put("proficiency", w.getWeaknessScore());
                m.put("evidenceCount", w.getEvidenceCount());
                return m;
            }).collect(Collectors.toList());
            fired.add(buildAlert(sid, student.getClassId(), "weakness_worsening", 3,
                    Map.of("weaknesses", weakInfo), teacherId));
        }

        // 规则5：问诊行为异常（低）
        Long msgCount = null;
        if (!sessions.isEmpty()) {
            ChatSession latest = sessions.get(0);
            msgCount = messageLogMapper.selectCount(
                    new LambdaQueryWrapper<ChatMessageLog>()
                            .eq(ChatMessageLog::getSessionId, latest.getId()));
        }
        if (msgCount != null && (msgCount < 3 || msgCount > 30)) {
            fired.add(buildAlert(sid, student.getClassId(), "behavior_abnormal", 1,
                    Map.of("lastSessionMessages", msgCount, "expectedRange", "3-30"), teacherId));
        }
    }

    private StudentAlert buildAlert(Long studentId, Long classId, String type, int level,
                                    Map<String, Object> detail, Long teacherId) {
        // 同类型未处理的预警不重复创建（幂等）
        StudentAlert exist = alertMapper.selectOne(
                new LambdaQueryWrapper<StudentAlert>()
                        .eq(StudentAlert::getStudentId, studentId)
                        .eq(StudentAlert::getAlertType, type)
                        .eq(StudentAlert::getStatus, 0)
                        .last("LIMIT 1"));
        if (exist != null) {
            return exist;
        }
        StudentAlert alert = new StudentAlert();
        alert.setStudentId(studentId);
        alert.setClassId(classId);
        alert.setAlertType(type);
        alert.setRiskLevel(level);
        alert.setStatus(0);
        try {
            alert.setRuleDetailJson(objectMapper.writeValueAsString(detail));
        } catch (Exception e) {
            alert.setRuleDetailJson("{}");
        }
        alertMapper.insert(alert);

        // 站内信推送
        SysUser student = userMapper.selectById(studentId);
        String typeName = switch (type) {
            case "osce_low" -> "OSCE连续低分";
            case "assignment_overdue" -> "作业逾期";
            case "daily_break" -> "每日一例断档";
            case "weakness_worsening" -> "薄弱知识点持续";
            default -> "问诊行为异常";
        };
        String levelName = level == 3 ? "高" : level == 2 ? "中" : "低";
        SysNotification n = new SysNotification();
        n.setRecipientId(teacherId);
        n.setNotifyType("alert");
        n.setTitle("学情预警【" + levelName + "风险】" + typeName);
        n.setContent("学生「" + (student != null ? student.getRealName() : studentId)
                + "」触发" + typeName + "预警，请查看预警中心。");
        n.setRefId(alert.getId());
        n.setIsRead(0);
        notificationMapper.insert(n);
        return alert;
    }

    // ---------------- 查询接口 ----------------

    @Override
    public Map<String, Object> overview() {
        Long teacherId = UserContext.requireUserId();
        List<Long> classIds = authorizedClassIds(teacherId);
        List<StudentAlert> alerts = classIds.isEmpty() ? List.of()
                : alertMapper.selectList(new LambdaQueryWrapper<StudentAlert>()
                        .in(StudentAlert::getClassId, classIds)
                        .eq(StudentAlert::getStatus, 0));

        Map<String, Object> result = new HashMap<>();
        result.put("pendingCount", alerts.size());
        result.put("highCount", alerts.stream().filter(a -> a.getRiskLevel() != null && a.getRiskLevel() == 3).count());
        result.put("mediumCount", alerts.stream().filter(a -> a.getRiskLevel() != null && a.getRiskLevel() == 2).count());
        result.put("lowCount", alerts.stream().filter(a -> a.getRiskLevel() != null && a.getRiskLevel() == 1).count());
        // 类型分布
        Map<String, Long> byType = alerts.stream()
                .collect(Collectors.groupingBy(StudentAlert::getAlertType, Collectors.counting()));
        result.put("byType", byType);
        return result;
    }

    @Override
    public List<Map<String, Object>> list(Long classId, Integer level) {
        Long teacherId = UserContext.requireUserId();
        List<Long> classIds = authorizedClassIds(teacherId);
        LambdaQueryWrapper<StudentAlert> qw = new LambdaQueryWrapper<StudentAlert>()
                .eq(StudentAlert::getStatus, 0);
        if (classIds.isEmpty()) return List.of();
        if (classId != null) {
            qw.eq(StudentAlert::getClassId, classId);
        } else {
            qw.in(StudentAlert::getClassId, classIds);
        }
        if (level != null) qw.eq(StudentAlert::getRiskLevel, level);
        qw.orderByDesc(StudentAlert::getRiskLevel).orderByDesc(StudentAlert::getCreatedAt);

        List<StudentAlert> alerts = alertMapper.selectList(qw);
        Map<Long, SysUser> userMap = new HashMap<>();
        if (!alerts.isEmpty()) {
            userMapper.selectBatchIds(alerts.stream().map(StudentAlert::getStudentId).distinct().toList())
                    .forEach(u -> userMap.put(u.getId(), u));
        }
        return alerts.stream().map(a -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", a.getId());
            m.put("studentId", a.getStudentId());
            SysUser u = userMap.get(a.getStudentId());
            m.put("studentName", u != null ? u.getRealName() : String.valueOf(a.getStudentId()));
            m.put("classId", a.getClassId());
            m.put("alertType", a.getAlertType());
            m.put("riskLevel", a.getRiskLevel());
            m.put("ruleDetail", a.getRuleDetailJson());
            m.put("intervention", a.getInterventionJson());
            m.put("createdAt", a.getCreatedAt());
            return m;
        }).toList();
    }

    @Override
    public Map<String, Object> detail(Long studentId) {
        List<StudentAlert> alerts = alertMapper.selectList(
                new LambdaQueryWrapper<StudentAlert>()
                        .eq(StudentAlert::getStudentId, studentId)
                        .orderByDesc(StudentAlert::getCreatedAt)
                        .last("LIMIT 20"));
        SysUser student = userMapper.selectById(studentId);
        // 薄弱点
        List<StudentWeakness> weaknesses = weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, studentId)
                        .orderByAsc(StudentWeakness::getWeaknessScore)
                        .last("LIMIT 10"));
        Map<String, Object> result = new HashMap<>();
        result.put("studentId", studentId);
        result.put("studentName", student != null ? student.getRealName() : "");
        result.put("alerts", alerts.stream().map(a -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", a.getId());
            m.put("alertType", a.getAlertType());
            m.put("riskLevel", a.getRiskLevel());
            m.put("ruleDetail", a.getRuleDetailJson());
            m.put("status", a.getStatus());
            m.put("intervention", a.getInterventionJson());
            m.put("createdAt", a.getCreatedAt());
            return m;
        }).toList());
        result.put("weaknesses", weaknesses.stream().map(w -> {
            Map<String, Object> m = new HashMap<>();
            m.put("knowledgeTag", w.getKnowledgeTag());
            m.put("proficiency", w.getWeaknessScore());
            m.put("evidenceCount", w.getEvidenceCount());
            return m;
        }).toList());
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> intervene(Long studentId) {
        List<StudentAlert> active = alertMapper.selectList(
                new LambdaQueryWrapper<StudentAlert>()
                        .eq(StudentAlert::getStudentId, studentId)
                        .eq(StudentAlert::getStatus, 0));
        if (active.isEmpty()) {
            throw new BizException(ResultCode.NOT_FOUND, "该学生暂无未处理预警");
        }
        SysUser student = userMapper.selectById(studentId);

        // 组装 AI 入参（只传真实数据）
        List<Map<String, Object>> riskRules = active.stream().map(a -> {
            Map<String, Object> m = new HashMap<>();
            m.put("type", a.getAlertType());
            m.put("level", a.getRiskLevel());
            m.put("detail", a.getRuleDetailJson());
            return m;
        }).collect(Collectors.toList());

        List<StudentWeakness> weaknesses = weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, studentId)
                        .orderByAsc(StudentWeakness::getWeaknessScore)
                        .last("LIMIT 5"));
        List<Map<String, Object>> weakList = weaknesses.stream().map(w -> {
            Map<String, Object> m = new HashMap<>();
            m.put("knowledgeTag", w.getKnowledgeTag());
            m.put("proficiency", w.getWeaknessScore());
            return m;
        }).collect(Collectors.toList());

        Map<String, Object> intervention = aiPlatformClient.alertIntervention(
                student != null ? student.getRealName() : "", riskRules, weakList,
                List.of(), List.of(), List.of());

        if (intervention != null) {
            try {
                String json = objectMapper.writeValueAsString(intervention);
                for (StudentAlert a : active) {
                    a.setInterventionJson(json);
                    a.setStatus(2);
                    a.setResolvedAt(LocalDateTime.now());
                    alertMapper.updateById(a);
                }
            } catch (Exception e) {
                log.warn("保存干预建议失败: {}", e.getMessage());
            }
        }
        return intervention;
    }

    @Override
    public void markResolved(Long alertId) {
        StudentAlert alert = alertMapper.selectById(alertId);
        if (alert == null) {
            throw new BizException(ResultCode.NOT_FOUND, "预警不存在");
        }
        alert.setStatus(1);
        alertMapper.updateById(alert);
    }

    // ---------------- 定时任务（每天 8 点全量扫描） ----------------

    @Scheduled(cron = "0 0 8 * * ?")
    public void scheduledScan() {
        log.info("定时学情预警扫描开始");
        List<SysUser> teachers = userMapper.selectList(
                new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, 1));
        for (SysUser t : teachers) {
            try {
                // 用教师上下文扫描：直接遍历该教师班级学生（复用 UserContext 不适用定时任务）
                List<Long> classIds = authorizationMapper.selectList(
                                new LambdaQueryWrapper<TeacherClassAuthorization>()
                                        .eq(TeacherClassAuthorization::getTeacherId, t.getId()))
                        .stream().map(TeacherClassAuthorization::getClassId).toList();
                if (classIds.isEmpty()) continue;
                List<SysUser> students = userMapper.selectList(
                        new LambdaQueryWrapper<SysUser>()
                                .eq(SysUser::getRole, 0).eq(SysUser::getStatus, 0)
                                .in(SysUser::getClassId, classIds));
                for (SysUser s : students) {
                    scanStudent(s, t.getId(), classIds);
                }
            } catch (Exception e) {
                log.warn("定时扫描教师{}班级失败: {}", t.getId(), e.getMessage());
            }
        }
        log.info("定时学情预警扫描完成");
    }

    // ---------------- 私有方法 ----------------

    private List<Long> authorizedClassIds(Long teacherId) {
        return authorizationMapper.selectList(
                        new LambdaQueryWrapper<TeacherClassAuthorization>()
                                .eq(TeacherClassAuthorization::getTeacherId, teacherId))
                .stream().map(TeacherClassAuthorization::getClassId).toList();
    }

    private double parseOsceTotal(String osceScoreJson) {
        if (osceScoreJson == null || osceScoreJson.isBlank()) return 0;
        try {
            JsonNode scores = objectMapper.readTree(osceScoreJson).path("scores");
            if (scores.isObject()) {
                double sum = 0;
                for (JsonNode n : scores) sum += n.asDouble(0);
                return sum;
            }
        } catch (Exception ignored) {
        }
        return 0;
    }

    private boolean hasLowDimension(String osceScoreJson) {
        if (osceScoreJson == null || osceScoreJson.isBlank()) return false;
        try {
            JsonNode scores = objectMapper.readTree(osceScoreJson).path("scores");
            if (scores.isObject()) {
                for (JsonNode n : scores) {
                    if (n.asDouble(0) < DIM_LOW_THRESHOLD) return true;
                }
            }
        } catch (Exception ignored) {
        }
        return false;
    }
}
