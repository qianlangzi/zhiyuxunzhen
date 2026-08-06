package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.service.TeacherAiService;
import com.zhiyu.service.dto.CaseDraftDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
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
    private final MedicalRecordReviewMapper reviewMapper;
    private final ChatSessionMapper chatSessionMapper;
    private final SpCaseConfigMapper caseMapper;
    private final TeachingClassMapper classMapper;
    private final SysUserMapper userMapper;
    private final StudentMistakesMapper mistakesMapper;
    private final StudentWeaknessMapper weaknessMapper;

    // ==================== 1. AI 生成 SP 病例草稿 ====================

    @Override
    public Map<String, Object> generateCaseDraft(CaseDraftDTO req) {
        return aiPlatformClient.generateCaseDraft(
                req.getChiefComplaint(),
                req.getDepartment(),
                req.getDifficulty(),
                req.getTeachingGoals());
    }

    // ==================== 2. AI 班级学情洞察 ====================

    @Override
    public Map<String, Object> classInsight(Long teacherId) {
        // 1. 该教师全部作业 → 实例 → 学生
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>().eq(Assignment::getTeacherId, teacherId));
        if (assignments == null || assignments.isEmpty()) {
            return aiPlatformClient.classInsight("", List.of(), Map.of(), List.of());
        }
        List<Long> assignmentIds = assignments.stream().map(Assignment::getId).toList();
        List<AssignmentInstance> instances = instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>().in(AssignmentInstance::getAssignmentId, assignmentIds));
        if (instances.isEmpty()) {
            return aiPlatformClient.classInsight("", List.of(), Map.of(), List.of());
        }
        List<Long> instanceIds = instances.stream().map(AssignmentInstance::getId).toList();
        List<Long> studentIds = instances.stream().map(AssignmentInstance::getStudentId)
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
        Map<String, Integer> osceScores = aggregateOsceScores(studentIds);

        // 4. 共性错题（从 student_mistakes 聚合）
        List<Map<String, Object>> commonMistakes = aggregateCommonMistakes(studentIds);

        // 5. 组装统计
        List<Map<String, Object>> stats = new ArrayList<>();
        stats.add(Map.of("label", "作业完成率", "value",
                instances.isEmpty() ? "0%" : String.format("%.0f%%", 100.0 * completed / instances.size())));
        stats.add(Map.of("label", "平均批阅分", "value", String.format("%.1f", avgScore)));
        stats.add(Map.of("label", "参与学生数", "value", String.valueOf(studentIds.size())));
        stats.add(Map.of("label", "批阅记录数", "value", String.valueOf(reviews.size())));

        return aiPlatformClient.classInsight("", stats, osceScores, commonMistakes);
    }

    // ==================== 3. AI 复核辅助 ====================

    @Override
    public Map<String, Object> reviewAssist(Long instanceId) {
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.NOT_FOUND, "作业实例不存在");
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
        TeachingClass clazz = classMapper.selectById(classId);
        if (clazz == null) {
            throw new BizException(ResultCode.NOT_FOUND, "班级不存在");
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
        Long teacherId = com.zhiyu.common.context.UserContext.requireUserId();
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
        SpCaseConfig c = caseMapper.selectById(caseId);
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
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
        SpCaseConfig c = caseMapper.selectById(caseId);
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        return aiPlatformClient.practiceQuestions(
                caseId,
                c.getHiddenDisease(),
                parseStringList(c.getStandardPathJson()),
                parseStringList(c.getKnowledgeTags()));
    }

    // ==================== 私有辅助 ====================

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

    /** 从 student_mistakes 聚合共性错题（按知识点标签计数，取前 8） */
    private List<Map<String, Object>> aggregateCommonMistakes(List<Long> studentIds) {
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
                .limit(8)
                .map(e -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("type", "错题");
                    m.put("description", e.getKey());
                    m.put("count", e.getValue().intValue());
                    return m;
                })
                .collect(Collectors.toList());
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