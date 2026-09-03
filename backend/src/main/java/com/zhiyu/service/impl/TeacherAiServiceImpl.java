package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentTargetClass;
import com.zhiyu.entity.LearningDiagnosis;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.TeacherClassAuthorization;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.AssignmentTargetClassMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.LearningDiagnosisMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TeacherClassAuthorizationMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.service.TeacherAiService;
import com.zhiyu.service.dto.CaseDraftDTO;
import com.zhiyu.service.support.OsceStatsHelper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 教师端 AI 辅助服务实现（PRD 4.1 / 9.3 扩展）
 *
 * 负责：组装真实业务数据 → 调用 AI 中台 → 返回结构化结果。
 * 所有 AI 不可用时返回 null，由 Controller 统一输出友好提示，保证教师主流程不受影响。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherAiServiceImpl implements TeacherAiService {

    private final AiPlatformClient aiPlatformClient;
    private final ObjectMapper objectMapper;

    private final AssignmentMapper assignmentMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentTargetClassMapper targetClassMapper;
    private final MedicalRecordReviewMapper reviewMapper;
    private final ChatSessionMapper chatSessionMapper;
    private final SpCaseConfigMapper caseMapper;
    private final TeachingClassMapper classMapper;
    private final SysUserMapper userMapper;
    private final StudentMistakesMapper mistakesMapper;
    private final StudentWeaknessMapper weaknessMapper;
    private final TeacherClassAuthorizationMapper classAuthMapper;
    private final LearningDiagnosisMapper diagnosisMapper;

    // ==================== 1. AI 生成 SP 病例草稿 ====================

    @Override
    public Map<String, Object> generateCaseDraft(CaseDraftDTO req) {
        return aiPlatformClient.generateCaseDraft(
                req.getChiefComplaint(),
                req.getDepartment(),
                req.getDifficulty(),
                req.getTeachingGoals(),
                req.getRemark());
    }

    // ==================== 2. AI 班级学情洞察 ====================

    @Override
    public Map<String, Object> classInsight(Long teacherId, Long classId) {
        Map<String, Object> agg = aggregateClassStats(teacherId, classId);
        return aiPlatformClient.classInsight(
                (String) agg.get("className"),
                (List<Map<String, Object>>) agg.get("stats"),
                (Map<String, Integer>) agg.get("osceScores"),
                (List<Map<String, Object>>) agg.get("commonMistakes"));
    }

    /**
     * 聚合指定班级（classId 为空时汇总该教师全体学生）的真实学情统计快照。
     * 返回 key：className / stats / osceScores / commonMistakes。
     */
    private Map<String, Object> aggregateClassStats(Long teacherId, Long classId) {
        String className = "";
        List<Long> studentIds;
        // 1. 定位范围：优先按班级过滤；classId 为空时回退到该教师全部学生（兼容旧调用）
        if (classId != null) {
            TeachingClass clazz = classMapper.selectById(classId);
            if (clazz == null) {
                throw new BizException(ResultCode.NOT_FOUND, "班级不存在");
            }
            // 归属校验：仅限已授权给当前教师的班级，防教师聚合任意班级学生数据
            boolean authorized = classAuthMapper.selectCount(
                    new LambdaQueryWrapper<TeacherClassAuthorization>()
                            .eq(TeacherClassAuthorization::getTeacherId, teacherId)
                            .eq(TeacherClassAuthorization::getClassId, classId)) > 0;
            if (!authorized) {
                throw new BizException(ResultCode.FORBIDDEN, "当前班级未授权给该教师");
            }
            className = clazz.getName() == null ? "" : clazz.getName();
            studentIds = userMapper.selectList(
                            new LambdaQueryWrapper<SysUser>()
                                    .eq(SysUser::getClassId, classId)
                                    .eq(SysUser::getRole, 0))
                    .stream().map(SysUser::getId).toList();
        } else {
            studentIds = List.of();
        }

        // 该教师布置的作业
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>().eq(Assignment::getTeacherId, teacherId));
        List<Long> teacherAssignmentIds = assignments == null || assignments.isEmpty()
                ? List.of()
                : assignments.stream().map(Assignment::getId).toList();

        // 按班级过滤：仅统计面向该班级的作业
        Set<Long> scopedAssignmentIds = (classId == null)
                ? new HashSet<>(teacherAssignmentIds)
                : queryTargetAssignmentIds(teacherAssignmentIds, classId);
        if (scopedAssignmentIds.isEmpty()) {
            return emptyClassStats(className);
        }

        List<AssignmentInstance> instances = instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>()
                        .in(AssignmentInstance::getAssignmentId, scopedAssignmentIds));
        if (classId != null && !studentIds.isEmpty()) {
            // 再收窄为班级学生，双重复核
            Set<Long> classStudentSet = new HashSet<>(studentIds);
            instances = instances.stream()
                    .filter(i -> i.getStudentId() != null && classStudentSet.contains(i.getStudentId()))
                    .toList();
        }
        if (instances.isEmpty()) {
            return emptyClassStats(className);
        }
        List<Long> instanceIds = instances.stream().map(AssignmentInstance::getId).toList();
        studentIds = instances.stream().map(AssignmentInstance::getStudentId)
                .filter(Objects::nonNull).distinct().toList();

        // 2. 批阅记录 → 平均分 / 完成数
        List<MedicalRecordReview> reviews = reviewMapper.selectList(
                new LambdaQueryWrapper<MedicalRecordReview>().in(MedicalRecordReview::getInstanceId, instanceIds));
        double avgScore = reviews.stream()
                .map(MedicalRecordReview::getTotalScore)
                .filter(Objects::nonNull)
                .mapToDouble(BigDecimal::doubleValue)
                .average().orElse(0.0);
        long completed = instances.stream().filter(i -> i.getStatus() != null && i.getStatus() >= 4).count();

        // 3. OSCE 维度均分（从 chat_session.osceScoreJson 聚合）
        Map<String, Integer> osceScores = OsceStatsHelper.aggregateOsceScores(chatSessionMapper, objectMapper, studentIds);

        // 4. 共性错题（从 student_mistakes 聚合，取前 8）
        List<Map<String, Object>> commonMistakes = OsceStatsHelper.aggregateCommonMistakes(mistakesMapper, studentIds, 8);

        // 5. 组装统计
        List<Map<String, Object>> stats = new ArrayList<>();
        stats.add(Map.of("label", "作业完成率", "value",
                instances.isEmpty() ? "0%" : String.format("%.0f%%", 100.0 * completed / instances.size())));
        stats.add(Map.of("label", "平均批阅分", "value", String.format("%.1f", avgScore)));
        stats.add(Map.of("label", "参与学生数", "value", String.valueOf(studentIds.size())));
        stats.add(Map.of("label", "批阅记录数", "value", String.valueOf(reviews.size())));

        Map<String, Object> agg = new LinkedHashMap<>();
        agg.put("className", className);
        agg.put("stats", stats);
        agg.put("osceScores", osceScores);
        agg.put("commonMistakes", commonMistakes);
        return agg;
    }

    /** 无可用数据时的空统计快照 */
    private Map<String, Object> emptyClassStats(String className) {
        Map<String, Object> agg = new LinkedHashMap<>();
        agg.put("className", className == null ? "" : className);
        agg.put("stats", List.of());
        agg.put("osceScores", Map.of());
        agg.put("commonMistakes", List.of());
        return agg;
    }

    /** 查询该教师布置的、面向指定班级的作业 ID 集合 */
    private Set<Long> queryTargetAssignmentIds(List<Long> assignmentIds, Long classId) {
        List<AssignmentTargetClass> targets = targetClassMapper.selectList(
                new LambdaQueryWrapper<AssignmentTargetClass>()
                        .in(AssignmentTargetClass::getAssignmentId, assignmentIds)
                        .eq(AssignmentTargetClass::getClassId, classId));
        return targets.stream().map(AssignmentTargetClass::getAssignmentId)
                .filter(Objects::nonNull).collect(Collectors.toSet());
    }

    // ==================== 3. AI 复核辅助 ====================

    @Override
    public Map<String, Object> reviewAssist(Long instanceId) {
        Long teacherId = com.zhiyu.common.context.UserContext.requireUserId();
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.NOT_FOUND, "作业实例不存在");
        }
        // B-P0-2 修复（采用 main 的更严格实现）：归属校验——只能辅助复核本人布置作业的实例。
        // 旧实现无校验，教师可读任意 instanceId 的学生病历全文。
        Assignment assignment = inst.getAssignmentId() == null ? null
                : assignmentMapper.selectById(inst.getAssignmentId());
        if (assignment == null) {
            throw new BizException(ResultCode.ASSIGNMENT_NOT_FOUND);
        }
        if (!teacherId.equals(assignment.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能辅助复核本人布置作业的实例");
        }
        // 最新 AI 批阅
        List<MedicalRecordReview> reviews = reviewMapper.selectList(
                new LambdaQueryWrapper<MedicalRecordReview>()
                        .eq(MedicalRecordReview::getInstanceId, instanceId)
                        .eq(MedicalRecordReview::getReviewerType, "AI")
                        .orderByDesc(MedicalRecordReview::getCreatedAt));
        MedicalRecordReview aiReview = reviews.isEmpty() ? null : reviews.get(0);
        List<Map<String, Object>> aiMistakes = parseList(aiReview == null ? null : aiReview.getMistakesJson());
        double aiScore = aiReview == null || aiReview.getTotalScore() == null
                ? 0.0 : aiReview.getTotalScore().doubleValue();

        // 病例标准路径上下文
        String caseContext = buildCaseContext(inst.getCaseId());

        return aiPlatformClient.reviewAssist(
                instanceId,
                inst.getMedicalRecordText(),
                aiScore,
                aiMistakes,
                caseContext);
    }

    // ==================== 4. AI 推荐作业病例 ====================

    @Override
    public Map<String, Object> recommendCases(Long classId) {
        Long teacherId = com.zhiyu.common.context.UserContext.requireUserId();
        TeachingClass clazz = classMapper.selectById(classId);
        if (clazz == null) {
            throw new BizException(ResultCode.NOT_FOUND, "班级不存在");
        }
        // B-P0-2 修复：归属校验——仅限已授权给当前教师的班级（防教师聚合任意班级学生薄弱点）
        boolean authorized = classAuthMapper.selectCount(
                new LambdaQueryWrapper<TeacherClassAuthorization>()
                        .eq(TeacherClassAuthorization::getTeacherId, teacherId)
                        .eq(TeacherClassAuthorization::getClassId, classId)) > 0;
        if (!authorized) {
            throw new BizException(ResultCode.FORBIDDEN, "当前班级未授权给该教师");
        }
        // 班级学生
        List<Long> studentIds = userMapper.selectList(
                        new LambdaQueryWrapper<SysUser>()
                                .eq(SysUser::getClassId, classId)
                                .eq(SysUser::getRole, 0))
                .stream().map(SysUser::getId).toList();

        // 班级薄弱点（从 student_weakness 聚合，取薄弱度最高的前 8 个）
        List<Map<String, Object>> weaknesses = aggregateWeaknesses(studentIds);

        // 候选病例库：该教师自己创建的已发布病例
        List<SpCaseConfig> myCases = caseMapper.selectList(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getCreatorId, teacherId)
                        .eq(SpCaseConfig::getStatus, 1));
        List<Map<String, Object>> candidateCases = myCases.stream().map(c -> {
            Map<String, Object> m = new HashMap<>();
            m.put("caseId", c.getId());
            m.put("title", c.getTitle());
            m.put("knowledgeTags", parseList(c.getKnowledgeTags()));
            m.put("difficulty", c.getDifficulty() == null ? 2 : c.getDifficulty());
            return m;
        }).toList();

        return aiPlatformClient.recommendCases(classId, weaknesses, candidateCases);
    }

    // ==================== 5. AI 病例质检 ====================

    @Override
    public Map<String, Object> qualityCheck(Long caseId) {
        // B-P0-2 修复：只有病例创建者才能查看 hiddenDisease/standardPathJson（答案核心）。
        Long teacherId = com.zhiyu.common.context.UserContext.requireUserId();
        SpCaseConfig c = requireOwnCase(caseId, teacherId);
        return aiPlatformClient.qualityCheck(
                caseId,
                c.getTitle(),
                c.getHiddenDisease(),
                parseStringList(c.getStandardPathJson()),
                parseList(c.getPresetExams()),
                parseStringList(c.getKnowledgeTags()));
    }

    // ==================== 6. AI 自动生成练习题 ====================

    @Override
    public Map<String, Object> practiceQuestions(Long caseId) {
        // B-P0-2 修复：只有病例创建者才能基于 hiddenDisease/standardPathJson 生成练习题。
        Long teacherId = com.zhiyu.common.context.UserContext.requireUserId();
        SpCaseConfig c = requireOwnCase(caseId, teacherId);
        return aiPlatformClient.practiceQuestions(
                caseId,
                c.getHiddenDisease(),
                parseStringList(c.getStandardPathJson()),
                parseStringList(c.getKnowledgeTags()));
    }

    // ==================== 7. 学情诊断报告（P1-1） ====================

    @Override
    public Map<String, Object> generateClassReport(Long classId) {
        Long teacherId = UserContext.requireUserId();
        Map<String, Object> agg = aggregateClassStats(teacherId, classId);
        String configuredName = classId == null ? "全体学生"
                : StringUtils.hasText((String) agg.get("className"))
                        ? (String) agg.get("className") : "全体学生";

        // AI 归纳班级洞察；不可用时降级为纯统计快照，仍生成可查看的报告
        Map<String, Object> aiResult = null;
        try {
            aiResult = aiPlatformClient.classInsight(
                    (String) agg.get("className"),
                    (List<Map<String, Object>>) agg.get("stats"),
                    (Map<String, Integer>) agg.get("osceScores"),
                    (List<Map<String, Object>>) agg.get("commonMistakes"));
        } catch (Exception e) {
            log.warn("学情诊断报告 AI 归纳失败，降级为统计快照: {}", e.getMessage());
        }

        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("className", agg.get("className"));
        snapshot.put("stats", agg.get("stats"));
        snapshot.put("osceScores", agg.get("osceScores"));
        snapshot.put("commonMistakes", agg.get("commonMistakes"));
        snapshot.put("ai", aiResult == null ? Map.of() : aiResult);

        LearningDiagnosis d = new LearningDiagnosis();
        d.setTeacherId(teacherId);
        d.setClassId(classId);
        d.setClassName(configuredName);
        d.setTitle(configuredName + " · 学情诊断报告");
        d.setSummaryJson(toJson(snapshot));
        d.setSource(aiResult == null ? "RULE" : "AI");
        d.setStatus(aiResult == null ? "DEGRADED" : "SUCCESS");
        diagnosisMapper.insert(d);
        return detailView(d);
    }

    @Override
    public List<Map<String, Object>> listDiagnosisReports() {
        Long teacherId = UserContext.requireUserId();
        List<LearningDiagnosis> list = diagnosisMapper.selectList(
                new LambdaQueryWrapper<LearningDiagnosis>()
                        .eq(LearningDiagnosis::getTeacherId, teacherId)
                        .orderByDesc(LearningDiagnosis::getCreatedAt));
        return list.stream().map(this::listView).toList();
    }

    @Override
    public Map<String, Object> getDiagnosisReport(Long id) {
        Long teacherId = UserContext.requireUserId();
        LearningDiagnosis d = requireOwnReport(id, teacherId);
        return detailView(d);
    }

    @Override
    public void deleteDiagnosisReport(Long id) {
        Long teacherId = UserContext.requireUserId();
        requireOwnReport(id, teacherId);
        diagnosisMapper.deleteById(id);
    }

    /** 校验报告存在且属于当前教师，返回实体 */
    private LearningDiagnosis requireOwnReport(Long id, Long teacherId) {
        LearningDiagnosis d = diagnosisMapper.selectById(id);
        if (d == null) {
            throw new BizException(ResultCode.NOT_FOUND, "学情诊断报告不存在");
        }
        if (d.getTeacherId() == null || !teacherId.equals(d.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能操作本人生成的报告");
        }
        return d;
    }

    /** 列表视图（不含完整快照） */
    private Map<String, Object> listView(LearningDiagnosis d) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", d.getId());
        m.put("classId", d.getClassId());
        m.put("className", d.getClassName());
        m.put("title", d.getTitle());
        m.put("source", d.getSource());
        m.put("status", d.getStatus());
        m.put("createdAt", d.getCreatedAt());
        return m;
    }

    /** 详情视图（含完整快照） */
    private Map<String, Object> detailView(LearningDiagnosis d) {
        Map<String, Object> m = listView(d);
        m.put("summary", parseObjMap(d.getSummaryJson()));
        return m;
    }

    /** 对象序列化为 JSON 字符串；失败返回 "{}" */
    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            log.warn("序列化失败: {}", e.getMessage());
            return "{}";
        }
    }

    /** 解析 JSON 对象字符串为 Map；为空或非法返回空 Map */
    private Map<String, Object> parseObjMap(String json) {
        if (!StringUtils.hasText(json)) return Map.of();
        try {
            JsonNode node = objectMapper.readTree(json);
            if (node.isObject()) {
                return objectMapper.convertValue(node, Map.class);
            }
        } catch (Exception e) {
            log.warn("解析 JSON 对象失败: {}", e.getMessage());
        }
        return Map.of();
    }

    // ==================== 私有辅助 ====================

    /** 校验病例存在且属于当前教师创建，返回病例实体 */
    private SpCaseConfig requireOwnCase(Long caseId, Long teacherId) {
        SpCaseConfig c = caseMapper.selectById(caseId);
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        if (c.getCreatorId() == null || !teacherId.equals(c.getCreatorId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能操作本人创建的病例");
        }
        return c;
    }

    /** 从 student_weakness 聚合班级薄弱知识点（取薄弱度最高的前 8 个） */
    private List<Map<String, Object>> aggregateWeaknesses(List<Long> studentIds) {
        if (studentIds.isEmpty()) return List.of();
        List<StudentWeakness> weaknesses = weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .in(StudentWeakness::getStudentId, studentIds));
        return weaknesses.stream()
                .filter(w -> w.getKnowledgeTag() != null && w.getWeaknessScore() != null)
                .collect(Collectors.groupingBy(StudentWeakness::getKnowledgeTag))
                .entrySet().stream()
                .map(e -> {
                    double avg = e.getValue().stream()
                            .mapToDouble(w -> w.getWeaknessScore().doubleValue())
                            .average().orElse(0.0);
                    Map<String, Object> m = new HashMap<>();
                    m.put("tag", e.getKey());
                    m.put("score", Math.round(avg * 100.0) / 100.0);
                    return m;
                })
                .sorted((a, b) -> Double.compare(
                        ((Number) b.get("score")).doubleValue(),
                        ((Number) a.get("score")).doubleValue()))
                .limit(8)
                .collect(Collectors.toList());
    }

    /** 构建病例标准路径上下文 */
    private String buildCaseContext(Long caseId) {
        if (caseId == null) return "";
        SpCaseConfig c = caseMapper.selectById(caseId);
        if (c == null) return "";
        StringBuilder sb = new StringBuilder();
        sb.append("标题：").append(c.getTitle() == null ? "" : c.getTitle()).append("\n");
        sb.append("隐藏疾病：").append(c.getHiddenDisease() == null ? "" : c.getHiddenDisease()).append("\n");
        List<String> path = parseStringList(c.getStandardPathJson());
        if (!path.isEmpty()) {
            sb.append("标准路径：\n");
            int i = 1;
            for (String step : path) {
                sb.append(i++).append(". ").append(step).append("\n");
            }
        }
        return sb.toString();
    }

    /** 解析 JSON 数组字符串为 List；为空或非法返回空列表 */
    private List<Map<String, Object>> parseList(String json) {
        if (!StringUtils.hasText(json)) return List.of();
        try {
            JsonNode node = objectMapper.readTree(json);
            if (node.isArray()) {
                List<Map<String, Object>> list = new ArrayList<>();
                node.forEach(item -> list.add(objectMapper.convertValue(item, Map.class)));
                return list;
            }
        } catch (Exception e) {
            log.warn("解析 JSON 数组失败: {}", e.getMessage());
        }
        return List.of();
    }

    /** 解析 JSON 字符串数组为 List<String>；为空或非法返回空列表 */
    private List<String> parseStringList(String json) {
        if (!StringUtils.hasText(json)) return List.of();
        try {
            JsonNode node = objectMapper.readTree(json);
            if (node.isArray()) {
                List<String> list = new ArrayList<>();
                node.forEach(item -> {
                    if (item.isTextual()) {
                        list.add(item.asText());
                    } else {
                        list.add(item.toString());
                    }
                });
                return list;
            }
        } catch (Exception e) {
            log.warn("解析 JSON 字符串数组失败: {}", e.getMessage());
        }
        return List.of();
    }
}