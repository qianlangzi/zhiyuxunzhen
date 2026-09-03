package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.StudentPracticeRecord;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.StudentPracticeRecordMapper;
import com.zhiyu.service.StudentReportService;
import com.zhiyu.vo.StudentLearningOverviewVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.LinkedHashMap;

/**
 * 学生成长概览服务
 *
 * 原「复盘报告导出（export / AI PDF 生成 / 审计）」链路已于 2026-09-02 下线，
 * 本服务仅保留成长页依赖的 overview：能力评分（OSCE 四维均值）+ 近 90 天活动热力图。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentReportServiceImpl implements StudentReportService {

    private final ChatSessionMapper sessionMapper;
    private final ObjectMapper objectMapper;
    private final StudentPracticeRecordMapper practiceRecordMapper;

    @Override
    public StudentLearningOverviewVO overview() {
        Long studentId = UserContext.requireUserId();
        LocalDate start = LocalDate.now().minusDays(89);
        List<ChatSession> sessions = sessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>()
                        .eq(ChatSession::getStudentId, studentId)
                        .ge(ChatSession::getCreatedAt, start.atStartOfDay())
                        .orderByAsc(ChatSession::getCreatedAt));
        // 学习热力图改为统计「每日刷题次数」（基础题题库作答记录）
        List<StudentPracticeRecord> practiceRecords = practiceRecordMapper.selectList(
                new LambdaQueryWrapper<StudentPracticeRecord>()
                        .eq(StudentPracticeRecord::getStudentId, studentId)
                        .ge(StudentPracticeRecord::getAnsweredAt, start.atStartOfDay()));

        Map<LocalDate, Integer> counts = new HashMap<>();
        practiceRecords.forEach(item -> counts.merge(item.getAnsweredAt().toLocalDate(), 1, Integer::sum));
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
}
