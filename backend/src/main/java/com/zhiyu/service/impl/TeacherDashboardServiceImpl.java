package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.TeacherClassAuthorization;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.TeacherClassAuthorizationMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.service.TeacherDashboardService;
import com.zhiyu.service.support.OsceStatsHelper;
import com.zhiyu.vo.TeacherDashboardVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
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
    private final SpCaseConfigMapper caseMapper;
    private final TeachingClassMapper classMapper;
    private final TeacherClassAuthorizationMapper classAuthMapper;
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
        Map<String, Integer> dimensionScores = OsceStatsHelper.aggregateOsceScores(chatSessionMapper, objectMapper, studentIds);

        // 5. 共性错题（student_mistakes，按知识点计数）
        List<TeacherDashboardVO.CommonMistake> commonMistakes = aggregateCommonMistakes(studentIds);

        // 6. 过度检查率（chat_session.totalExamCost 聚合，简单估算：超过均值的会话占比）
        double overExamRate = computeOverExamRate(studentIds);

        // ===== 首页工作台实时计数（代替前端硬编码假数据） =====
        // 待复核：status=4（AI已批阅，待教师人工复核）
        int pendingReview = (int) instances.stream()
                .filter(i -> i.getStatus() != null && i.getStatus() == 4).count();
        // 进行中的作业：当前名下全部作业数
        int activeAssignments = assignments == null ? 0 : assignments.size();
        // 本人病例数
        int myCases = myCases(teacherId);
        // 被授权班级数
        int classCount = teachingClassCount(teacherId);
        // 病例广场累计引用与均分（本人发布的公开病例）
        Map<String, Object> market = marketSummary(teacherId);

        return TeacherDashboardVO.builder()
                .completionRate(total == 0 ? 0.0 : (double) completed / total)
                .avgOsceScore(reviews.isEmpty() ? 0.0 : avgScore)
                .reviewEfficiency(reviews.isEmpty() ? 0.0 : reviews.size() / Math.max(1.0, (double) total))
                .overExamRate(overExamRate)
                .osceDimensionScores(dimensionScores)
                .commonMistakes(commonMistakes)
                .pendingReview(pendingReview)
                .activeAssignments(activeAssignments)
                .myCases(myCases)
                .classCount(classCount)
                .marketRefs(market.get("refs") == null ? 0 : (Integer) market.get("refs"))
                .marketRating(market.get("rating") == null ? null : (Double) market.get("rating"))
                .build();
    }

    /** 从 student_mistakes 聚合共性错题（通过公共组件聚合，映射为看板 VO，取前 5） */
    private List<TeacherDashboardVO.CommonMistake> aggregateCommonMistakes(List<Long> studentIds) {
        return OsceStatsHelper.aggregateCommonMistakes(mistakesMapper, studentIds, 5).stream()
                .map(m -> TeacherDashboardVO.CommonMistake.builder()
                        .type((String) m.get("type"))
                        .description((String) m.get("description"))
                        .count((Integer) m.get("count"))
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

    /** 本人病例数 */
    private int myCases(Long teacherId) {
        Long count = caseMapper.selectCount(
                new LambdaQueryWrapper<SpCaseConfig>().eq(SpCaseConfig::getCreatorId, teacherId));
        return count == null ? 0 : count.intValue();
    }

    /** 被授权班级数（仅统计处于有效状态的教学班） */
    private int teachingClassCount(Long teacherId) {
        List<Long> ids = classAuthMapper.selectList(
                new LambdaQueryWrapper<TeacherClassAuthorization>()
                        .eq(TeacherClassAuthorization::getTeacherId, teacherId))
                .stream().map(TeacherClassAuthorization::getClassId).toList();
        if (ids.isEmpty()) return 0;
        Long count = classMapper.selectCount(
                new LambdaQueryWrapper<TeachingClass>().in(TeachingClass::getId, ids));
        return count == null ? 0 : count.intValue();
    }

    /** 本人发布到广场的病例累计引用量与平均评分 */
    private Map<String, Object> marketSummary(Long teacherId) {
        List<SpCaseConfig> published = caseMapper.selectList(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getCreatorId, teacherId)
                        .eq(SpCaseConfig::getIsPublic, true));
        int refs = published.stream()
                .map(SpCaseConfig::getReferenceCount)
                .filter(Objects::nonNull)
                .mapToInt(Integer::intValue).sum();
        double avg = published.stream()
                .map(SpCaseConfig::getRatingAvg)
                .filter(Objects::nonNull)
                .mapToDouble(BigDecimal::doubleValue)
                .average().orElse(0.0);
        Map<String, Object> result = new HashMap<>();
        result.put("refs", refs);
        result.put("rating", published.isEmpty() ? null : avg);
        return result;
    }
}