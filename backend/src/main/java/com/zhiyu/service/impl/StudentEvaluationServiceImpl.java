package com.zhiyu.service.impl;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.StudentEvaluationService;
import com.zhiyu.vo.OsceHistoryVO;
import com.zhiyu.vo.SessionEvaluationVO;
import com.zhiyu.vo.ThinkingTreeVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 学生会话评估服务实现
 *
 * 直接读取 ChatSession 表中由 AI 中台归档写入的字段：
 *   - osceScoreJson     : evaluator 输出的 scores（4 维）
 *   - finalReport       : evaluator 的 final_report
 *   - reasoningTreeJson : evaluator 完整 result JSON（含 scores/comments/strengths/
 *                         improvements/final_report/mistakes），同时也可作为思维树来源
 *   - totalExamCost     : 累计检查费用
 *
 * 维度对齐 ai/app/agents/evaluator_agent.py 的 4 维：history / logic / communication / humanity。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentEvaluationServiceImpl implements StudentEvaluationService {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final ChatSessionMapper sessionMapper;
    private final SpCaseConfigMapper caseMapper;
    private final ObjectMapper objectMapper;

    @Override
    public List<OsceHistoryVO> history() {
        Long studentId = UserContext.requireUserId();
        List<ChatSession> sessions = sessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>()
                        .eq(ChatSession::getStudentId, studentId)
                        .eq(ChatSession::getStatus, 1)
                        .orderByDesc(ChatSession::getEndedAt));

        List<Long> caseIds = sessions.stream()
                .map(ChatSession::getCaseId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, SpCaseConfig> cMap = new HashMap<>();
        if (!caseIds.isEmpty()) {
            for (SpCaseConfig c : caseMapper.selectList(
                    new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, caseIds))) {
                cMap.put(c.getId(), c);
            }
        }

        return sessions.stream().map(s -> {
            Map<String, Object> scores = parseJson(s.getOsceScoreJson(), MAP_TYPE, Collections.emptyMap());
            double total = 0.0;
            for (Object v : scores.values()) {
                total += toDouble(v);
            }
            SpCaseConfig c = cMap.get(s.getCaseId());
            return OsceHistoryVO.builder()
                    .sessionId(s.getId())
                    .caseId(s.getCaseId())
                    .caseTitle(c == null ? null : c.getTitle())
                    .department(c == null ? null : c.getDepartment())
                    .totalScore(total)
                    .osceScoreJson(s.getOsceScoreJson())
                    .totalExamCost(s.getTotalExamCost())
                    .status(s.getStatus())
                    .endedAt(s.getEndedAt())
                    .createdAt(s.getCreatedAt())
                    .build();
        }).collect(Collectors.toList());
    }

    @Override
    public SessionEvaluationVO getEvaluation(Long sessionId) {
        ChatSession session = requireSession(sessionId);

        Map<String, Object> scores = parseJson(session.getOsceScoreJson(), MAP_TYPE, Collections.emptyMap());
        Map<String, Object> comments = Collections.emptyMap();
        List<String> strengths = Collections.emptyList();
        List<String> improvements = Collections.emptyList();
        List<Map<String, Object>> mistakes = Collections.emptyList();
        double totalScore = 0.0;

        // reasoningTreeJson 是 evaluator 的完整 result，可从中提取 comments/strengths/improvements/mistakes
        Map<String, Object> tree = parseJson(session.getReasoningTreeJson(), MAP_TYPE, Collections.emptyMap());
        if (!tree.isEmpty()) {
            comments = asMap(tree.get("comments"), Collections.emptyMap());
            strengths = asStringList(tree.get("strengths"));
            improvements = asStringList(tree.get("improvements"));
            mistakes = asMapList(tree.get("mistakes"));
            // evaluator 的 scores 也可能在 tree 中（兜底）
            if (scores.isEmpty() && tree.get("scores") instanceof Map) {
                scores = asMap(tree.get("scores"), Collections.emptyMap());
            }
        }

        // 总分 = 四维相加（每维 0-25，总分 0-100）
        if (!scores.isEmpty()) {
            for (Object v : scores.values()) {
                totalScore += toDouble(v);
            }
        }

        return SessionEvaluationVO.builder()
                .sessionId(session.getId())
                .caseId(session.getCaseId())
                .scores(scores)
                .comments(comments)
                .strengths(strengths)
                .improvements(improvements)
                .finalReport(session.getFinalReport())
                .mistakes(mistakes)
                .totalScore(totalScore)
                .status(session.getStatus())
                .build();
    }

    @Override
    public ThinkingTreeVO getThinkingTree(Long sessionId) {
        ChatSession session = requireSession(sessionId);

        Map<String, Object> tree = parseJson(session.getReasoningTreeJson(), MAP_TYPE, Collections.emptyMap());
        List<Map<String, Object>> nodes = asMapList(tree.get("nodes"));
        List<Map<String, Object>> edges = asMapList(tree.get("edges"));
        String socraticPrompt = tree.get("socrates_hint") instanceof String s ? s : null;
        String currentStage = tree.get("current_stage") instanceof String s ? s : null;

        Double totalExamCost = session.getTotalExamCost() == null
                ? 0.0 : session.getTotalExamCost().doubleValue();

        return ThinkingTreeVO.builder()
                .sessionId(session.getId())
                .totalExamCost(totalExamCost)
                .nodes(nodes)
                .edges(edges)
                .socraticPrompt(socraticPrompt)
                .currentStage(currentStage)
                .build();
    }

    private ChatSession requireSession(Long sessionId) {
        ChatSession session = sessionMapper.selectById(sessionId);
        if (session == null) {
            throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在");
        }
        // B-P0-1 修复：归属校验——只有会话的创建学生才能查看自己的 OSCE 评估、思维树、最终报告。
        // 旧实现只按 sessionId 查库，任何学生枚举 sessionId 即可读取他人问诊的病历数据。
        Long currentUserId = UserContext.requireUserId();
        if (!currentUserId.equals(session.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN, "无权访问该会话");
        }
        return session;
    }

    private <T> T parseJson(String json, TypeReference<T> type, T fallback) {
        if (json == null || json.isBlank()) return fallback;
        try {
            return objectMapper.readValue(json, type);
        } catch (Exception e) {
            log.warn("解析会话 JSON 字段失败: sessionId={} error={}", json, e.getMessage());
            return fallback;
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> asMap(Object obj, Map<String, Object> fallback) {
        if (obj instanceof Map) {
            return new LinkedHashMap<>((Map<String, Object>) obj);
        }
        return fallback;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> asMapList(Object obj) {
        if (obj instanceof List<?> list) {
            List<Map<String, Object>> result = new ArrayList<>(list.size());
            for (Object item : list) {
                if (item instanceof Map) {
                    result.add((Map<String, Object>) item);
                }
            }
            return result;
        }
        return Collections.emptyList();
    }

    @SuppressWarnings("unchecked")
    private List<String> asStringList(Object obj) {
        if (obj instanceof List<?> list) {
            List<String> result = new ArrayList<>(list.size());
            for (Object item : list) {
                if (item != null) result.add(item.toString());
            }
            return result;
        }
        return Collections.emptyList();
    }

    private double toDouble(Object v) {
        if (v instanceof Number n) return n.doubleValue();
        if (v instanceof String s) {
            try { return Double.parseDouble(s); } catch (NumberFormatException ignored) {}
        }
        return 0.0;
    }
}
