package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.AuditLog;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.AuditLogMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.StudentReportService;
import com.zhiyu.service.dto.ExportReportDTO;
import com.zhiyu.vo.ReportSessionVO;
import com.zhiyu.vo.ReviewReportVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 学生复盘报告服务实现（PRD 4.11）
 * 简化实现：汇总问诊会话数据返回报告 JSON，并写审计日志（action=export_report）。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentReportServiceImpl implements StudentReportService {

    private final ChatSessionMapper sessionMapper;
    private final SpCaseConfigMapper caseMapper;
    private final AuditLogMapper auditLogMapper;
    private final ObjectMapper objectMapper;

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
            sessionVOs.add(ReportSessionVO.builder()
                    .sessionId(s.getId())
                    .caseId(s.getCaseId())
                    .caseTitle(s.getCaseId() == null ? null : titleMap.get(s.getCaseId()))
                    .status(s.getStatus())
                    .osceScoreJson(s.getOsceScoreJson())
                    .totalExamCost(cost)
                    .endedAt(s.getEndedAt())
                    .createdAt(s.getCreatedAt())
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
