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
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.service.StudentMistakeService;
import com.zhiyu.vo.MistakeVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
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

    /** 主观题（简答/论述）错题类型：走失分维度归因，区别于客观题的临床推理分叉归因 */
    public static final String SUBJECTIVE_TYPE = "essay";
    private static final String QUESTION_TYPE_OBJECTIVE = "objective";
    private static final String QUESTION_TYPE_SUBJECTIVE = "subjective";

    private final StudentMistakesMapper mistakesMapper;
    private final SpCaseConfigMapper caseMapper;
    private final PracticeQuestionMapper questionMapper;
    private final AiPlatformClient aiPlatformClient;
    private final ObjectMapper objectMapper;
    private final StudentPaperServiceImpl studentPaperService;

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

        // 批量补全刷题错题的题干
        List<Long> questionIds = records.stream()
                .map(StudentMistakes::getQuestionId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, String> questionTitleMap = new HashMap<>();
        if (!questionIds.isEmpty()) {
            for (PracticeQuestion pq : questionMapper.selectList(
                    new LambdaQueryWrapper<PracticeQuestion>().in(PracticeQuestion::getId, questionIds))) {
                questionTitleMap.put(pq.getId(), pq.getTitle());
            }
        }

        List<MistakeVO> list = records.stream().map(m -> MistakeVO.builder()
                .id(m.getId())
                .caseId(m.getCaseId())
                .caseTitle(m.getCaseId() == null ? null : titleMap.get(m.getCaseId()))
                .questionId(m.getQuestionId())
                .questionTitle(m.getQuestionId() == null ? null : questionTitleMap.get(m.getQuestionId()))
                .sessionId(m.getSessionId())
                .mistakeType(m.getMistakeType())
                .knowledgeTag(m.getKnowledgeTag())
                .studentAnswer(m.getStudentAnswer())
                .standardAnswer(m.getStandardAnswer())
                .evidenceJson(m.getEvidenceJson())
                .aiAnalysis(parseAnalysisJson(m.getAiAnalysisJson()))
                .aiStatus(extractStatus(m.getAiAnalysisJson()))
                .resolvedStatus(m.getResolvedStatus())
                .consecutiveCorrect(m.getConsecutiveCorrect())
                .wrongCount(m.getWrongCount())
                .focusFlag(m.getFocusFlag())
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
        if (hasSuccessCache(m.getAiAnalysisJson())) {
            return parseAnalysisMap(m.getAiAnalysisJson());
        }
        return callAiAndCache(m, studentId);
    }

    /**
     * 异步预生成归因：静默执行，失败只记日志，不影响主链路。
     */
    @Override
    public void generateAnalysis(Long mistakeId, Long studentId) {
        if (mistakeId == null || studentId == null) {
            return;
        }
        StudentMistakes m = mistakesMapper.selectById(mistakeId);
        if (m == null || !studentId.equals(m.getStudentId())) {
            return;
        }
        if (hasSuccessCache(m.getAiAnalysisJson())) {
            return;
        }
        try {
            callAiAndCache(m, studentId);
        } catch (Exception e) {
            log.warn("错题归因预生成失败: mistakeId={} err={}", mistakeId, e.getMessage());
        }
    }

    private boolean hasSuccessCache(String json) {
        Map<String, Object> cached = parseAnalysisMap(json);
        return cached != null && "SUCCESS".equals(cached.get("status"));
    }

    /**
     * 调用 AI 归因并落缓存；AI 不可用时返回 DEGRADED（不落缓存，允许下次重试）。
     */
    private Map<String, Object> callAiAndCache(StudentMistakes m, Long studentId) {
        String caseTitle = null;
        if (m.getCaseId() != null) {
            SpCaseConfig c = caseMapper.selectById(m.getCaseId());
            if (c != null) caseTitle = c.getTitle();
        }
        boolean subjective = SUBJECTIVE_TYPE.equals(m.getMistakeType());
        Map<String, Object> ai = aiPlatformClient.analyzeMistake(
                m.getId(), studentId, m.getMistakeType(), m.getKnowledgeTag(),
                caseTitle, buildQuestionText(m), m.getStudentAnswer(), m.getStandardAnswer(),
                m.getEvidenceJson(),
                subjective ? QUESTION_TYPE_SUBJECTIVE : QUESTION_TYPE_OBJECTIVE,
                null, null);
        if (ai == null || !"SUCCESS".equals(ai.get("status"))) {
            Map<String, Object> degraded = new HashMap<>();
            degraded.put("mistakeId", m.getId());
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
            update.setId(m.getId());
            update.setAiAnalysisJson(objectMapper.writeValueAsString(ai));
            mistakesMapper.updateById(update);
        } catch (Exception e) {
            log.warn("错题归因结果缓存失败: mistakeId={} error={}", m.getId(), e.getMessage());
        }
        return ai;
    }

    /**
     * 练同类题：以「错题知识点 + AI 归因推荐标签」为焦点生成巩固练习。
     */
    @Override
    public Map<String, Object> generateDrill(Long mistakeId, int count) {
        Long studentId = UserContext.requireUserId();
        StudentMistakes m = mistakesMapper.selectById(mistakeId);
        if (m == null || !studentId.equals(m.getStudentId())) {
            throw new BizException(ResultCode.NOT_FOUND, "错题不存在或无权访问");
        }
        List<String> tags = new ArrayList<>();
        if (StringUtils.hasText(m.getKnowledgeTag())) {
            tags.add(m.getKnowledgeTag().trim());
        }
        Map<String, Object> ai = parseAnalysisMap(m.getAiAnalysisJson());
        if (ai != null && "SUCCESS".equals(ai.get("status")) && ai.get("recommendedTags") instanceof List<?> list) {
            for (Object o : list) {
                String t = o == null ? "" : String.valueOf(o).trim();
                if (!t.isEmpty() && !tags.contains(t)) {
                    tags.add(t);
                }
            }
        }
        // 标签为空时组卷会失去焦点，退回错题知识点仍为空则直接报业务错
        if (tags.isEmpty()) {
            throw new BizException(ResultCode.BAD_REQUEST, "该错题暂无知识点标签，无法生成巩固练习");
        }
        com.zhiyu.service.dto.PaperGenerateRequest req = new com.zhiyu.service.dto.PaperGenerateRequest();
        req.setCount(count <= 0 ? 5 : count);
        req.setFocusTags(tags);
        req.setKnowledgeTags(tags);
        Map<String, Object> paper = studentPaperService.generateFor(studentId, req);
        paper.put("mistakeId", mistakeId);
        paper.put("drillTags", tags);
        return paper;
    }

    /**
     * 构造给 AI 的题干文本。
     *
     * <p>刷题错题此前固定传 null，导致 AI 只能看到学生的选项字母（如 "A"）与标准答案，
     * 看不到题干与选项内容，归因只能靠猜。这里补齐「题干 + 选项」。
     */
    private String buildQuestionText(StudentMistakes m) {
        if (m.getQuestionId() == null) {
            return null;
        }
        PracticeQuestion q = questionMapper.selectById(m.getQuestionId());
        if (q == null) {
            return null;
        }
        StringBuilder sb = new StringBuilder();
        if (StringUtils.hasText(q.getTitle())) {
            sb.append(q.getTitle());
        }
        if (StringUtils.hasText(q.getOptionsJson())) {
            sb.append("\n选项：").append(q.getOptionsJson());
        }
        return sb.length() == 0 ? null : sb.toString();
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

    /**
     * 人工回写错题状态（闭环出口）：仅可置 0/1/2，且必须先校验归属。
     * 置「已掌握(2)」时同步把连续答对数抬高到阈值，保证与自动判掌握口径一致；
     * 置回未复习且累计答错>=2 时补「需加强」标记。
     */
    @Override
    public void markResolved(Long mistakeId, Integer resolvedStatus) {
        Long studentId = UserContext.requireUserId();
        StudentMistakes m = mistakesMapper.selectById(mistakeId);
        if (m == null || !studentId.equals(m.getStudentId())) {
            throw new BizException(ResultCode.NOT_FOUND, "错题不存在或无权访问");
        }
        int target = resolvedStatus == null ? 0 : resolvedStatus;
        if (target < 0 || target > 2) {
            throw new BizException(ResultCode.BAD_REQUEST, "无效的错题状态");
        }
        int wrong = m.getWrongCount() == null ? 0 : m.getWrongCount();
        StudentMistakes upd = new StudentMistakes();
        upd.setId(mistakeId);
        upd.setResolvedStatus(target);
        if (target == 2) {
            // 手动掌握：与自动判定阈值保持一致（连续答对数视为已达标）
            upd.setConsecutiveCorrect(PracticeQuestionServiceImpl.MISTAKE_MASTER_THRESHOLD);
        } else if (target == 0) {
            // 退回未复习：若累计错>=2 补「需加强」
            upd.setConsecutiveCorrect(0);
            upd.setFocusFlag(wrong >= 2 ? 1 : 0);
        }
        mistakesMapper.updateById(upd);
    }
}
