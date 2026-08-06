package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.service.TeacherDashboardService;
import com.zhiyu.vo.TeacherDashboardVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 教师学情看板服务实现（真实聚合）
 *
 * 从 assignment_instance / medical_record_review / chat_session / student_mistakes / student_weakness
 * 五张表聚合该教师名下作业的真实统计数据，替代原 mock。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherDashboardServiceImpl implements TeacherDashboardService {

    private final AssignmentMapper assignmentMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final MedicalRecordReviewMapper reviewMapper;
    private final ChatSessionMapper chatSessionMapper;
    private final StudentMistakesMapper mistakesMapper;
    private final ObjectMapper objectMapper;

    @Override
    public TeacherDashboardVO getOverview(Long teacherId) {
        // 1. 该教师全部作业 → 实例
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>().eq(Assignment::getTeacherId, teacherId));
        List<AssignmentInstance> instances = List.of();
        if (assignments != null && !assignments.isEmpty()) {
            List<Long> assignmentIds = assignments.stream().map(Assignment::getId).toList();
            instances = instanceMapper.selectList(
                    new LambdaQueryWrapper<AssignmentInstance>().in(AssignmentInstance::getAssignmentId, assignmentIds));
        }

        // 2. 完成率（status>=4 视为已完成）
        int total = instances.size();
        long completed = instances.stream()
                .filter(i -> i.getStatus() != null && i.getStatus() >= 4).count();

        // 3. 批阅记录 → 平均分 / 批阅效率
        List<Long> instanceIds = instances.stream().map(AssignmentInstance::getId).toList();
        List<MedicalRecordReview> reviews = instanceIds.isEmpty() ? List.of() : reviewMapper.selectList(
                new LambdaQueryWrapper<MedicalRecordReview>().in(MedicalRecordReview::getInstanceId, instanceIds));
        double avgScore = reviews.stream()
                .map(MedicalRecordReview::getTotalScore)
                .filter(Objects::nonNull)
                .mapToDouble(BigDecimal::doubleValue)
                .average().orElse(0.0);

        // 4. OSCE 维度均分（chat_session.osceScoreJson）
        List<Long> studentIds = instances.stream().map(AssignmentInstance::getStudentId)
                .filter(Objects::nonNull).distinct().toList();
        Map<String, Integer> dimensionScores = aggregateOsceScores(studentIds);

        // 5. 共性错题（student_mistakes，按知识点计数）
        List<TeacherDashboardVO.CommonMistake> commonMistakes = aggregateCommonMistakes(studentIds);

        // 6. 过度检查率（chat_session.totalExamCost 聚合，简单估算：超过均值的会话占比）
        double overExamRate = computeOverExamRate(studentIds);

        return TeacherDashboardVO.builder()
                .completionRate(total == 0 ? 0.0 : (double) completed / total)
                .avgOsceScore(reviews.isEmpty() ? 0.0 : avgScore)
                .reviewEfficiency(reviews.isEmpty() ? 0.0 : reviews.size() / Math.max(1.0, (double) total))
                .overExamRate(overExamRate)
                .osceDimensionScores(dimensionScores)
                .commonMistakes(commonMistakes)
                .build();
    }

    /** 从 chat_session.osceScoreJson 聚合各维度均分 */
    private Map<String, Integer> aggregateOsceScores(List<Long> studentIds) {
        List<ChatSession> sessions = studentIds.isEmpty() ? List.of() : chatSessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>().in(ChatSession::getStudentId, studentIds));
        Map<String, List<Double>> dims = new LinkedHashMap<>();
        for (ChatSession s : sessions) {
            if (!StringUtils.hasText(s.getOsceScoreJson())) continue;
            try {
                JsonNode root = objectMapper.readTree(s.getOsceScoreJson());
                JsonNode scores = root.has("scores") ? root.get("scores") : root;
                if (scores.isObject()) {
                    scores.fields().forEachRemaining(e -> {
                        double v = e.getValue().isNumber() ? e.getValue().asDouble() : 0.0;
                        dims.computeIfAbsent(e.getKey(), k -> new ArrayList<>()).add(v);
                    });
                }
            } catch (Exception ignored) {
                // 单条解析失败不影响整体
            }
        }
        Map<String, Integer> result = new LinkedHashMap<>();
        dims.forEach((k, v) -> result.put(k, (int) Math.round(v.stream().mapToDouble(Double::doubleValue).average().orElse(0))));
        return result;
    }

    /** 从 student_mistakes 聚合共性错题（按知识点计数，取前 5） */
    private List<TeacherDashboardVO.CommonMistake> aggregateCommonMistakes(List<Long> studentIds) {
        if (studentIds.isEmpty()) return List.of();
        List<StudentMistakes> mistakes = mistakesMapper.selectList(
                new LambdaQueryWrapper<StudentMistakes>().in(StudentMistakes::getStudentId, studentIds));
        Map<String, Long> countByTag = mistakes.stream()
                .map(m -> m.getKnowledgeTag() != null && !m.getKnowledgeTag().isBlank()
                        ? m.getKnowledgeTag() : m.getMistakeType())
                .filter(Objects::nonNull)
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
        return countByTag.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(5)
                .map(e -> TeacherDashboardVO.CommonMistake.builder()
                        .type("错题")
                        .description(e.getKey())
                        .count(e.getValue().intValue())
                        .build())
                .collect(Collectors.toList());
    }

    /** 估算过度检查率：检查费用超过总体均值的已结束会话占比 */
    private double computeOverExamRate(List<Long> studentIds) {
        if (studentIds.isEmpty()) return 0.0;
        List<ChatSession> sessions = chatSessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>()
                        .in(ChatSession::getStudentId, studentIds));
        List<BigDecimal> costs = sessions.stream()
                .map(ChatSession::getTotalExamCost)
                .filter(Objects::nonNull)
                .toList();
        if (costs.isEmpty()) return 0.0;
        double avg = costs.stream().mapToDouble(BigDecimal::doubleValue).average().orElse(0.0);
        long over = costs.stream().filter(c -> c.doubleValue() > avg).count();
        return (double) over / costs.size();
    }
}