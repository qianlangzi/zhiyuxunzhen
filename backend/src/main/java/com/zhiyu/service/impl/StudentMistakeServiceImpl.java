package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.service.StudentMistakeService;
import com.zhiyu.vo.MistakeVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 学生错题本服务实现（PRD 4.11）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentMistakeServiceImpl implements StudentMistakeService {

    private final StudentMistakesMapper mistakesMapper;
    private final SpCaseConfigMapper caseMapper;
    private final AiPlatformClient aiPlatformClient;
    private final ObjectMapper objectMapper;

    @Override
    public PageResult<MistakeVO> myMistakes(Integer pageNum, Integer pageSize, String mistakeType) {
        Long studentId = UserContext.requireUserId();
        Page<StudentMistakes> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<StudentMistakes> wrapper = new LambdaQueryWrapper<StudentMistakes>()
                .eq(StudentMistakes::getStudentId, studentId)
                .eq(StringUtils.hasText(mistakeType), StudentMistakes::getMistakeType, mistakeType)
                .orderByDesc(StudentMistakes::getCreatedAt);
        mistakesMapper.selectPage(page, wrapper);

        List<StudentMistakes> records = page.getRecords();
        // 批量补全病例标题
        List<Long> caseIds = records.stream()
                .map(StudentMistakes::getCaseId)
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

        List<MistakeVO> list = records.stream().map(m -> MistakeVO.builder()
                .id(m.getId())
                .caseId(m.getCaseId())
                .caseTitle(m.getCaseId() == null ? null : titleMap.get(m.getCaseId()))
                .sessionId(m.getSessionId())
                .mistakeType(m.getMistakeType())
                .knowledgeTag(m.getKnowledgeTag())
                .studentAnswer(m.getStudentAnswer())
                .standardAnswer(m.getStandardAnswer())
                .evidenceJson(m.getEvidenceJson())
                .aiAnalysis(parseAnalysisJson(m.getAiAnalysisJson()))
                .aiStatus(extractStatus(m.getAiAnalysisJson()))
                .resolvedStatus(m.getResolvedStatus())
                .createdAt(m.getCreatedAt())
                .build()).collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    /**
     * 单条错题 AI 归因（缓存命中直接返回；未命中调用 AI 并持久化缓存；
     * AI 不可用时返回 status=DEGRADED 的可重试提示，不落缓存）。
     */
    @Override
    public Map<String, Object> analyzeMistake(Long mistakeId) {
        Long studentId = UserContext.requireUserId();
        StudentMistakes m = mistakesMapper.selectById(mistakeId);
        if (m == null || !studentId.equals(m.getStudentId())) {
            throw new BizException(ResultCode.NOT_FOUND, "错题不存在或无权访问");
        }
        // 缓存命中：仅复用已成功的结果，避免重复消耗 AI
        if (StringUtils.hasText(m.getAiAnalysisJson())) {
            Map<String, Object> cached = parseAnalysisMap(m.getAiAnalysisJson());
            if (cached != null && "SUCCESS".equals(cached.get("status"))) {
                return cached;
            }
        }
        String caseTitle = null;
        if (m.getCaseId() != null) {
            SpCaseConfig c = caseMapper.selectById(m.getCaseId());
            if (c != null) caseTitle = c.getTitle();
        }
        Map<String, Object> ai = aiPlatformClient.analyzeMistake(
                m.getId(), studentId, m.getMistakeType(), m.getKnowledgeTag(),
                caseTitle, null, m.getStudentAnswer(), m.getStandardAnswer(), m.getEvidenceJson());
        if (ai == null || !"SUCCESS".equals(ai.get("status"))) {
            Map<String, Object> degraded = new HashMap<>();
            degraded.put("mistakeId", mistakeId);
            degraded.put("rootCause", "");
            degraded.put("explanation", ai != null && ai.get("explanation") != null
                    ? String.valueOf(ai.get("explanation")) : "AI 归因服务暂时不可用，请稍后重试。");
            degraded.put("recommendedTags", List.of());
            degraded.put("practiceHint", "");
            degraded.put("source", "RULE");
            degraded.put("status", "DEGRADED");
            return degraded;
        }
        // 归因成功：持久化缓存，后续进入错题本直接复用
        try {
            StudentMistakes update = new StudentMistakes();
            update.setId(mistakeId);
            update.setAiAnalysisJson(objectMapper.writeValueAsString(ai));
            mistakesMapper.updateById(update);
        } catch (Exception e) {
            log.warn("错题归因结果缓存失败: mistakeId={} error={}", mistakeId, e.getMessage());
        }
        return ai;
    }

    /** 解析归因 JSON 为通用对象；失败/为空返回 null */
    private Object parseAnalysisJson(String json) {
        if (!StringUtils.hasText(json)) return null;
        try {
            return objectMapper.readValue(json, Object.class);
        } catch (Exception e) {
            log.warn("解析错题归因JSON失败: {}", e.getMessage());
            return null;
        }
    }

    private Map<String, Object> parseAnalysisMap(String json) {
        Object obj = parseAnalysisJson(json);
        return obj instanceof Map ? (Map<String, Object>) obj : null;
    }

    private String extractStatus(String json) {
        Map<String, Object> map = parseAnalysisMap(json);
        if (map == null) return null;
        return map.get("status") == null ? null : String.valueOf(map.get("status"));
    }
}
