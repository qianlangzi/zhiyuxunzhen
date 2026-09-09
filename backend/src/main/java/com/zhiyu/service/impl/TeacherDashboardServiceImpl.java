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
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * 教师学情看板服务实现（真实聚合）
 *
 * 从 assignment_instance / medical_record_review / chat_session / student_mistakes / student_weakness
 * 五张表聚合该教师名下作业的真实统计数据，替代原 mock。
 *
 * 性能设计（2026-09-09）：
 * <ul>
 *   <li>所有列表查询均限定聚合所需列，不把题干 / 病例档案 / 对话记录等大字段拉进堆；</li>
 *   <li>OSCE 维度均分与过度检查率共用同一次 chat_session 查询（旧实现查两遍）；</li>
 *   <li>结果按 teacherId+classId 做 60 秒进程内缓存 —— 看板是打开即看的高频页，
 *       而学情数字天然允许分钟级延迟；批阅/作业状态变化后最长 60 秒收敛。</li>
 * </ul>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherDashboardServiceImpl implements TeacherDashboardService {

    /** 看板结果缓存 TTL */
    private static final long OVERVIEW_CACHE_TTL_MS = 60 * 1000L;

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

    /** getOverview 结果缓存：teacherId:classId -> {vo, at} */
    private static final Map<String, CacheEntry> OVERVIEW_CACHE = new ConcurrentHashMap<>();

    private record CacheEntry(TeacherDashboardVO vo, long at) {
    }

    @Override
    public TeacherDashboardVO getOverview(Long teacherId, Long classId) {
        String key = teacherId + ":" + (classId == null ? 0 : classId);
        CacheEntry entry = OVERVIEW_CACHE.get(key);
        if (entry != null && System.currentTimeMillis() - entry.at() < OVERVIEW_CACHE_TTL_MS) {
            return entry.vo();
        }
        TeacherDashboardVO vo = buildOverview(teacherId, classId);
        OVERVIEW_CACHE.put(key, new CacheEntry(vo, System.currentTimeMillis()));
        // 简单防膨胀：缓存键量级 = 教师数 × 班级筛选数，超阈值整体清一次
        if (OVERVIEW_CACHE.size() > 512) {
            OVERVIEW_CACHE.clear();
        }
        return vo;
    }

    private TeacherDashboardVO buildOverview(Long teacherId, Long classId) {
        // 1. 该教师全部作业（只需 id 计数，不捞题目 / 要求等大字段）
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>()
                        .eq(Assignment::getTeacherId, teacherId)
                        .select(Assignment::getId, Assignment::getTeacherId));

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

        // 4. 批阅记录 → 平均分 / 批阅效率（只取分数字段）
        List<Long> instanceIds = instances.stream().map(AssignmentInstance::getId).toList();
        List<MedicalRecordReview> reviews = instanceIds.isEmpty() ? List.of() : reviewMapper.selectList(
                new LambdaQueryWrapper<MedicalRecordReview>()
                        .in(MedicalRecordReview::getInstanceId, instanceIds)
                        .select(MedicalRecordReview::getId, MedicalRecordReview::getInstanceId,
                                MedicalRecordReview::getTotalScore));
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

        // 6+8. OSCE 维度均分 + 过度检查率：共用同一次 chat_session 查询
        // （旧实现 aggregateOsceScores / computeOverExamRate 各查一遍全量会话）
        List<ChatSession> sessions = studentIds.isEmpty() ? List.of() : chatSessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>()
                        .in(ChatSession::getStudentId, studentIds)
                        .select(ChatSession::getId, ChatSession::getStudentId,
                                ChatSession::getOsceScoreJson, ChatSession::getTotalExamCost));
        Map<String, Integer> dimensionScores =
                OsceStatsHelper.aggregateOsceScores(sessions, objectMapper);
        double overExamRate = computeOverExamRate(sessions);

        // 7. 共性错题（student_mistakes，按知识点计数；helper 内已限定列）
        List<TeacherDashboardVO.CommonMistake> commonMistakes = aggregateCommonMistakes(studentIds);

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

    /** 该教师全部作业 → 全部实例（只取统计需要的四列，实例表含作答快照等大字段） */
    private List<AssignmentInstance> allInstances(List<Assignment> assignments) {
        if (assignments == null || assignments.isEmpty()) return List.of();
        List<Long> assignmentIds = assignments.stream().map(Assignment::getId).toList();
        return instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>()
                        .in(AssignmentInstance::getAssignmentId, assignmentIds)
                        .select(AssignmentInstance::getId, AssignmentInstance::getAssignmentId,
                                AssignmentInstance::getStudentId, AssignmentInstance::getStatus));
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

    /**
     * 估算过度检查率：检查费用超过总体均值的已结束会话占比。
     * 接收调用方已查好的会话列表（与 OSCE 聚合共用），不再重复查库。
     */
    private double computeOverExamRate(List<ChatSession> sessions) {
        if (sessions == null || sessions.isEmpty()) return 0.0;
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

    /** 本人发布到广场的病例累计引用量与平均评分（只取两列，病例表含患者档案等大字段） */
    private Map<String, Object> marketSummary(Long teacherId) {
        List<SpCaseConfig> published = caseMapper.selectList(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getCreatorId, teacherId)
                        .eq(SpCaseConfig::getIsPublic, true)
                        .select(SpCaseConfig::getId, SpCaseConfig::getReferenceCount,
                                SpCaseConfig::getRatingAvg));
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
