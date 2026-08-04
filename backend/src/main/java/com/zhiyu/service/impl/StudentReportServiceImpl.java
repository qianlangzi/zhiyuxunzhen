package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.AuditLog;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.DailyCaseSubmission;
import com.zhiyu.mapper.AuditLogMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.DailyCaseSubmissionMapper;
import com.zhiyu.service.StudentReportService;
import com.zhiyu.service.dto.ExportReportDTO;
import com.zhiyu.vo.ReportSessionVO;
import com.zhiyu.vo.ReviewReportVO;
import com.zhiyu.vo.StudentLearningOverviewVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;
import java.util.LinkedHashMap;

/**
 * 学生复盘报告服务实现（PRD 4.11 / 9.3）
 * 1. 汇总问诊会话数据生成报告 JSON
 * 2. 调用 FastAPI /report/generate_review_pdf 生成 PDF（按会话维度）
 * 3. AI 不可用时降级返回 JSON，不阻断导出流程
 * 4. 写审计日志（action=export_report）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentReportServiceImpl implements StudentReportService {

    private final ChatSessionMapper sessionMapper;
    private final SpCaseConfigMapper caseMapper;
    private final AuditLogMapper auditLogMapper;
    private final ObjectMapper objectMapper;
    private final AiPlatformClient aiPlatformClient;
    private final DailyCaseSubmissionMapper dailySubmissionMapper;

    @Override
    public StudentLearningOverviewVO overview() {
        Long studentId = UserContext.requireUserId();
        LocalDate start = LocalDate.now().minusDays(89);
        List<ChatSession> sessions = sessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>()
                        .eq(ChatSession::getStudentId, studentId)
                        .ge(ChatSession::getCreatedAt, start.atStartOfDay())
                        .orderByAsc(ChatSession::getCreatedAt));
        List<DailyCaseSubmission> daily = dailySubmissionMapper.selectList(
                new LambdaQueryWrapper<DailyCaseSubmission>()
                        .eq(DailyCaseSubmission::getStudentId, studentId)
                        .ge(DailyCaseSubmission::getSubmittedAt, start.atStartOfDay()));

        Map<LocalDate, Integer> counts = new HashMap<>();
        sessions.forEach(item -> counts.merge(item.getCreatedAt().toLocalDate(), 1, Integer::sum));
        daily.forEach(item -> counts.merge(item.getSubmittedAt().toLocalDate(), 1, Integer::sum));
        List<StudentLearningOverviewVO.ActivityDay> activity = counts.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> StudentLearningOverviewVO.ActivityDay.builder()
                        .date(entry.getKey()).completedCount(entry.getValue()).build())
                .toList();

        Map<String, Integer> sums = new LinkedHashMap<>();
        Map<String, Integer> samples = new HashMap<>();
        for (ChatSession session : sessions) {
            if (session.getOsceScoreJson() == null || session.getOsceScoreJson().isBlank()) continue;
            try {
                Map<?, ?> scores = objectMapper.readValue(session.getOsceScoreJson(), Map.class);
                for (Map.Entry<?, ?> entry : scores.entrySet()) {
                    if (entry.getValue() instanceof Number number) {
                        String key = entry.getKey().toString();
                        sums.merge(key, number.intValue(), Integer::sum);
                        samples.merge(key, 1, Integer::sum);
                    }
                }
            } catch (Exception e) {
                log.warn("忽略无法解析的 OSCE 评分: sessionId={}", session.getId());
            }
        }
        Map<String, Integer> averages = new LinkedHashMap<>();
        sums.forEach((key, sum) -> averages.put(key, Math.round((float) sum / samples.get(key))));
        int completed = (int) sessions.stream().filter(item -> Integer.valueOf(1).equals(item.getStatus())).count();
        return StudentLearningOverviewVO.builder()
                .abilityScores(averages).activityDays(activity)
                .completedSessionCount(completed).build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public ReviewReportVO export(ExportReportDTO req) {
        Long studentId = UserContext.requireUserId();

        LambdaQueryWrapper<ChatSession> wrapper = new LambdaQueryWrapper<ChatSession>()
                .eq(ChatSession::getStudentId, studentId);
        if (req.getSessionIds() != null && !req.getSessionIds().isEmpty()) {
            wrapper.in(ChatSession::getId, req.getSessionIds());
        }
        if (req.getDateStart() != null) {
            wrapper.ge(ChatSession::getCreatedAt, req.getDateStart().atStartOfDay());
        }
        if (req.getDateEnd() != null) {
            wrapper.le(ChatSession::getCreatedAt, req.getDateEnd().atTime(LocalTime.MAX));
        }
        wrapper.orderByDesc(ChatSession::getCreatedAt);
        List<ChatSession> sessions = sessionMapper.selectList(wrapper);

        // 批量补全病例标题
        List<Long> caseIds = sessions.stream()
                .map(ChatSession::getCaseId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, String> titleMap = new HashMap<>();
        if (!caseIds.isEmpty()) {
            for (SpCaseConfig c : caseMapper.selectList(
                    new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, caseIds))) {
                titleMap.put(c.getId(), c.getTitle());
            }
        }

        BigDecimal costSum = BigDecimal.ZERO;
        List<ReportSessionVO> sessionVOs = new ArrayList<>();
        for (ChatSession s : sessions) {
            BigDecimal cost = s.getTotalExamCost() == null ? BigDecimal.ZERO : s.getTotalExamCost();
            costSum = costSum.add(cost);

            // 仅对已完成的会话调用 AI 生成报告（PRD 4.11.3 / 9.3）
            // AI 不可用时降级返回 null，不阻断报告导出
            // PDF 生成是未来增强功能，当前仅保留扩展点，pdfUrl 暂为 null
            String pdfUrl = null;
            if (s.getStatus() != null && s.getStatus() == 1) {
                try {
                    Map<String, Object> reportData = aiPlatformClient.generateReviewPdf(s.getId());
                    // AI 返回的 JSON 报告数据暂不用于前端展示，仅保留扩展点
                } catch (Exception e) {
                    log.warn("AI生成报告失败，降级处理: sessionId={} error={}", s.getId(), e.getMessage());
                }
            }

            sessionVOs.add(ReportSessionVO.builder()
                    .sessionId(s.getId())
                    .caseId(s.getCaseId())
                    .caseTitle(s.getCaseId() == null ? null : titleMap.get(s.getCaseId()))
                    .status(s.getStatus())
                    .osceScoreJson(s.getOsceScoreJson())
                    .totalExamCost(cost)
                    .endedAt(s.getEndedAt())
                    .createdAt(s.getCreatedAt())
                    .pdfUrl(pdfUrl)
                    .build());
        }

        ReviewReportVO report = ReviewReportVO.builder()
                .studentId(studentId)
                .generatedAt(LocalDateTime.now())
                .sessionCount(sessions.size())
                .totalExamCostSum(costSum)
                .sessions(sessionVOs)
                .build();

        // 写审计日志
        AuditLog auditLog = new AuditLog();
        auditLog.setOperatorId(studentId);
        auditLog.setOperatorRole(0);
        auditLog.setAction("export_report");
        auditLog.setTargetType("review_report");
        auditLog.setAfterJson(toJson(report));
        auditLog.setCreatedAt(LocalDateTime.now());
        auditLogMapper.insert(auditLog);

        log.info("学生{}导出复盘报告，会话数={}", studentId, sessions.size());
        return report;
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            log.warn("JSON序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
