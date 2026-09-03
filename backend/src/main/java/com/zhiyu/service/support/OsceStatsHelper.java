package com.zhiyu.service.support;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * OSCE / 学情统计聚合通用工具。
 *
 * 抽取 TeacherAiServiceImpl 与 TeacherDashboardServiceImpl 中重复的
 * OSCE 分数聚合与共性错题聚合逻辑，供两端复用。
 */
public final class OsceStatsHelper {

    private OsceStatsHelper() {
    }

    /**
     * 从 chat_session.osceScoreJson 聚合各维度均分（取整）。
     *
     * @param chatSessionMapper 会话 Mapper
     * @param objectMapper      JSON 解析器
     * @param studentIds        学生 ID 列表（可为空）
     */
    public static Map<String, Integer> aggregateOsceScores(
            ChatSessionMapper chatSessionMapper,
            ObjectMapper objectMapper,
            List<Long> studentIds) {
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
        dims.forEach((k, v) -> result.put(k, (int) Math.round(v.stream()
                .mapToDouble(Double::doubleValue).average().orElse(0))));
        return result;
    }

    /**
     * 从 student_mistakes 聚合共性错题，按知识点标签计数后降序取前 limit 个。
     * 返回元素格式为 {type:"错题", description:知识点/错因, count:次数}。
     *
     * @param mistakesMapper 错题 Mapper
     * @param studentIds     学生 ID 列表（可为空）
     * @param limit          返回条数上限（<=0 时返回空列表）
     */
    public static List<Map<String, Object>> aggregateCommonMistakes(
            StudentMistakesMapper mistakesMapper,
            List<Long> studentIds,
            int limit) {
        if (studentIds.isEmpty() || limit <= 0) return List.of();
        List<StudentMistakes> mistakes = mistakesMapper.selectList(
                new LambdaQueryWrapper<StudentMistakes>().in(StudentMistakes::getStudentId, studentIds));
        Map<String, Long> countByTag = mistakes.stream()
                .map(m -> m.getKnowledgeTag() != null && !m.getKnowledgeTag().isBlank()
                        ? m.getKnowledgeTag() : m.getMistakeType())
                .filter(Objects::nonNull)
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
        return countByTag.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(limit)
                .map(e -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("type", "错题");
                    m.put("description", e.getKey());
                    m.put("count", e.getValue().intValue());
                    return m;
                })
                .collect(Collectors.toList());
    }
}