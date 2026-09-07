package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentClassMembership;
import com.zhiyu.entity.TeacherClassAuthorization;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentClassMembershipMapper;
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
import java.util.Set;
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
    private final StudentClassMembershipMapper membershipMapper;
    private final ObjectMapper objectMapper;

    @Override
    public TeacherDashboardVO getOverview(Long teacherId, Long classId) {
        // 1. 该教师全部作业
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>().eq(Assignment::getTeacherId, teacherId));

        // 指定班级时，仅统计该班学生维度的学情数据；
        // 未指定班级（classId 为 null）时统计教师名下全部作业的学生学情。
        Set<Long> classStudentIds = classId == null ? null : classStudentIds(classId);

        // 2. 实例：默认该教师全部作业的实例；按班级筛选时仅保留该班学生产生的实例
        List<AssignmentInstance> instances = allInstances(assignments);
        if (classStudentIds != null) {
            instances = instances.stream()
                    .filter(i -> i.getStudentId() != null && classStudentIds.contains(i.getStudentId()))
                    .toList();
        }

        // 3. 完成率（status>=4 视为已完成）
        int total = instances.size();
        long completed = instances.stream()
                .filter(i -> i.getStatus() != null && i.getStatus() >= 4).count();

        // 4. 批阅记录 → 平均分 / 批阅效率
        List<Long> instanceIds = instances.stream().map(AssignmentInstance::getId).toList();
        List<MedicalRecordReview> reviews = instanceIds.isEmpty() ? List.of() : reviewMapper.selectList(
                new LambdaQueryWrapper<MedicalRecordReview>().in(MedicalRecordReview::getInstanceId, instanceIds));
        double avgScore = reviews.stream()
                .map(MedicalRecordReview::getTotalScore)
                .filter(Objects::nonNull)
                .mapToDouble(BigDecimal::doubleValue)
                .average().orElse(0.0);

        // 5. 涉及学生集合：默认取全部实例的学生；按班级筛选时直接用该班学生
        List<Long> studentIds;
        if (classStudentIds != null) {
            studentIds = classStudentIds.stream().toList();
        } else {
            studentIds = instances.stream().map(AssignmentInstance::getStudentId)
                    .filter(Objects::nonNull).distinct().toList();
        }

        // 6. OSCE 维度均分（chat_session.osceScoreJson）
        Map<String, Integer> dimensionScores = OsceStatsHelper.aggregateOsceScores(chatSessionMapper, objectMapper, studentIds);

        // 7. 共性错题（student_mistakes，按知识点计数）
        List<TeacherDashboardVO.CommonMistake> commonMistakes = aggregateCommonMistakes(studentIds);

        // 8. 过度检查率（chat_session.totalExamCost 聚合）
        double overExamRate = computeOverExamRate(studentIds);

        // ===== 首页工作台实时计数 =====
        // 待复核：status=4（AI已批阅，待教师人工复核），按班级筛选时仅为该班实例
        int pendingReview = (int) instances.stream()
                .filter(i -> i.getStatus() != null && i.getStatus() == 4).count();
        // 进行中的作业数、本人病例数、被授权班级数、广场统计：仍为该教师全局指标
        int activeAssignments = assignments == null ? 0 : assignments.size();
        int myCases = myCases(teacherId);
        int classCount = teachingClassCount(teacherId);
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

    /** 该教师全部作业 → 全部实例 */
    private List<AssignmentInstance> allInstances(List<Assignment> assignments) {
        if (assignments == null || assignments.isEmpty()) return List.of();
        List<Long> assignmentIds = assignments.stream().map(Assignment::getId).toList();
        return instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>().in(AssignmentInstance::getAssignmentId, assignmentIds));
    }

    /** 指定班级的学生 id 集合（以 student_class_membership 多对多表为准） */
    private Set<Long> classStudentIds(Long classId) {
        return membershipMapper.selectList(
                        new LambdaQueryWrapper<StudentClassMembership>()
                                .eq(StudentClassMembership::getClassId, classId))
                .stream()
                .map(StudentClassMembership::getStudentId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
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