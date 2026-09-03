package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.StudentPaperService;
import com.zhiyu.service.dto.PaperGenerateRequest;
import com.zhiyu.vo.PracticeQuestionVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.Executor;
import java.util.stream.Collectors;

/**
 * 学生端 AI 组卷服务实现（P2-4）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentPaperServiceImpl implements StudentPaperService {

    /** 提供给 AI 的候选上限（足够 LLM 挑题又不撑爆上下文） */
    private static final int CANDIDATE_LIMIT = 40;
    /** 用于组卷判断的题干截断长度 */
    private static final int TITLE_TRUNCATE = 80;
    /** 难度偏好为空时按 简单→标准→困难 进阶 */
    private static final int[] DEFAULT_LADDER = {1, 2, 3};

    private final StudentWeaknessMapper weaknessMapper;
    private final PracticeQuestionMapper questionMapper;
    private final TextbookMapper textbookMapper;
    private final AiPlatformClient aiPlatformClient;
    private final ObjectMapper objectMapper;
    /** 组卷异步任务执行器（AI 批阅同款线程池，与主请求线程隔离） */
    private final Executor aiTaskExecutor;

    /** 内存态组卷任务存储：taskId -> {status, errorMessage, paper}（进程内即可满足自测轮询） */
    private final ConcurrentMap<String, Map<String, Object>> paperTaskStore = new ConcurrentHashMap<>();

    @Override
    public Map<String, Object> generate(PaperGenerateRequest req) {
        return generateFor(UserContext.requireUserId(), req);
    }

    @Override
    public Map<String, Object> submitTask(PaperGenerateRequest req) {
        Long studentId = UserContext.requireUserId();
        // 提交时先在请求线程校验 ID，随后在异步线程完成候选组装 + AI 选题 + 题目解析
        String taskId = UUID.randomUUID().toString();
        Map<String, Object> record = new LinkedHashMap<>();
        record.put("status", "PENDING");
        record.put("errorMessage", null);
        record.put("paper", null);
        paperTaskStore.put(taskId, record);

        aiTaskExecutor.execute(() -> {
            try {
                record.put("status", "RUNNING");
                Map<String, Object> paper = generateFor(studentId, req);
                record.put("paper", paper);
                record.put("status", "SUCCEEDED");
            } catch (Exception e) {
                log.error("组卷任务执行失败 taskId={}", taskId, e);
                record.put("status", "FAILED_FINAL");
                record.put("errorMessage", "组卷失败，请稍后重试");
            }
        });

        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("taskId", taskId);
        resp.put("status", "PENDING");
        return resp;
    }

    @Override
    public Map<String, Object> getTask(String taskId) {
        Map<String, Object> record = paperTaskStore.get(taskId);
        if (record == null) {
            throw new BizException(ResultCode.NOT_FOUND, "组卷任务不存在或已过期");
        }
        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("taskId", taskId);
        resp.put("status", record.get("status"));
        resp.put("errorMessage", record.get("errorMessage"));
        resp.put("paper", record.get("paper"));
        return resp;
    }

    /**
     * 组卷核心（供同步 generate 与异步任务共用）：给定学生 ID，做候选组装 → AI 选题 → 题目解析。
     */
    public Map<String, Object> generateFor(Long studentId, PaperGenerateRequest req) {
        int count = req.getCount() == null ? 10 : req.getCount();
        Integer difficulty = req.getDifficulty();

        // 1. 取薄弱知识点（指定优先，否则系统统计；越薄弱越靠前）
        List<String> focusTags = resolveFocusTags(studentId, req.getFocusTags());

        // 2. 抽取审核通过 + 上架的题库候选（薄弱点优先，其余通用补齐）
        List<PracticeQuestion> candidates = loadCandidates(focusTags, count);

        // 3. 组装 AI 候选（只给元数据，防幻觉）
        List<Map<String, Object>> aiCandidates = candidates.stream()
                .map(q -> {
                    Map<String, Object> c = new HashMap<>();
                    c.put("id", q.getId());
                    c.put("knowledgeTag", q.getKnowledgeTag() == null ? "" : q.getKnowledgeTag());
                    c.put("difficulty", q.getDifficulty());
                    c.put("questionType", q.getQuestionType() == null ? "" : q.getQuestionType());
                    c.put("title", truncate(q.getTitle(), TITLE_TRUNCATE));
                    return c;
                })
                .collect(Collectors.toList());

        // 4. 调用 AI 选题组卷；降级/失败回退规则组卷
        Map<String, Object> ai = aiPlatformClient.generatePaper(studentId, count, difficulty,
                focusTags, aiCandidates);
        List<Long> selectedIds = pickIds(ai);
        String paperTitle = ai == null ? "" : String.valueOf(ai.getOrDefault("paperTitle", ""));
        String rationale = ai == null ? "" : String.valueOf(ai.getOrDefault("rationale", ""));
        String source = ai == null ? "RULE" : String.valueOf(ai.getOrDefault("source", "RULE"));
        boolean aiOk = selectedIds != null && !selectedIds.isEmpty();

        List<PracticeQuestionVO> questions;
        if (aiOk) {
            questions = resolveQuestions(selectedIds);
            // AI 选的题不足 count 时，用候选中的其它题补齐
            if (questions.size() < count) {
                questions.addAll(fillUp(candidates, selectedIds, count - questions.size()));
            }
        } else {
            questions = ruleSelect(candidates, focusTags, count, difficulty);
            paperTitle = paperTitle.isBlank() ? buildRuleTitle(focusTags) : paperTitle;
            rationale = rationale.isBlank()
                    ? "AI 组卷暂不可用，已按薄弱知识点优先 + 难度进阶规则生成。"
                    : rationale;
            source = "RULE";
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("paperTitle", paperTitle.isBlank() ? "个性化自测卷" : paperTitle);
        result.put("rationale", rationale);
        result.put("weakTags", focusTags);
        result.put("source", source);
        result.put("status", aiOk ? "SUCCESS" : "DEGRADED");
        result.put("questions", questions);
        return result;
    }

    // ---------- 私有辅助 ----------

    private List<String> resolveFocusTags(Long studentId, List<String> specified) {
        if (specified != null && !specified.isEmpty()) {
            return specified.stream().filter(StringUtils::hasText).distinct()
                    .limit(5).collect(Collectors.toList());
        }
        List<StudentWeakness> list = weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, studentId)
                        .orderByAsc(StudentWeakness::getWeaknessScore)   // 越薄弱越靠前
                        .orderByDesc(StudentWeakness::getEvidenceCount));
        return list.stream()
                .map(StudentWeakness::getKnowledgeTag)
                .filter(StringUtils::hasText)
                .distinct()
                .limit(5)
                .collect(Collectors.toList());
    }

    /** 抽取候选：薄弱点对应题优先，其余从通用池补齐；控制总量避免撑爆上下文 */
    private List<PracticeQuestion> loadCandidates(List<String> focusTags, int count) {
        List<PracticeQuestion> all = questionMapper.selectList(
                new LambdaQueryWrapper<PracticeQuestion>()
                        .eq(PracticeQuestion::getStatus, 1)
                        .eq(PracticeQuestion::getAdminAuditStatus, 2)
                        .orderByAsc(PracticeQuestion::getDifficulty)
                        .orderByAsc(PracticeQuestion::getId));
        if (all.isEmpty()) {
            return all;
        }
        List<PracticeQuestion> picked = new ArrayList<>();
        if (focusTags != null && !focusTags.isEmpty()) {
            Set<String> tags = new LinkedHashSet<>(focusTags);
            for (PracticeQuestion q : all) {
                if (tags.contains(q.getKnowledgeTag())) {
                    picked.add(q);
                }
                if (picked.size() >= CANDIDATE_LIMIT) break;
            }
        }
        if (picked.size() < CANDIDATE_LIMIT) {
            Set<Long> used = picked.stream().map(PracticeQuestion::getId).collect(Collectors.toSet());
            for (PracticeQuestion q : all) {
                if (used.contains(q.getId())) continue;
                picked.add(q);
                used.add(q.getId());
                if (picked.size() >= CANDIDATE_LIMIT) break;
            }
        }
        // 至少保证能出一张卷（候选不足 count 时全量返回）
        int need = Math.max(count * 2, Math.min(count, CANDIDATE_LIMIT));
        return picked.size() > need ? picked.subList(0, need) : picked;
    }

    private List<Long> pickIds(Map<String, Object> ai) {
        if (ai == null) return List.of();
        Object raw = ai.get("selectedIds");
        if (!(raw instanceof List<?> list)) return List.of();
        List<Long> ids = new ArrayList<>();
        for (Object o : list) {
            try {
                ids.add(Long.valueOf(String.valueOf(o)));
            } catch (NumberFormatException ignored) {
                // 忽略非法 ID
            }
        }
        return ids;
    }

    private List<PracticeQuestionVO> resolveQuestions(List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return List.of();
        }
        List<PracticeQuestion> rows = questionMapper.selectBatchIds(ids);
        Map<Long, PracticeQuestion> byId = rows.stream()
                .collect(Collectors.toMap(PracticeQuestion::getId, q -> q, (a, b) -> a));
        Map<Long, String> tbTitles = loadTextbookTitles(rows);
        // 保持 AI 选题顺序
        List<PracticeQuestionVO> vos = new ArrayList<>();
        for (Long id : ids) {
            PracticeQuestion q = byId.get(id);
            if (q != null) {
                vos.add(toVO(q, tbTitles));
            }
        }
        return vos;
    }

    /** 规则组卷：薄弱点优先 + 难度进阶；无薄弱点时按难度分布取题 */
    private List<PracticeQuestionVO> ruleSelect(List<PracticeQuestion> candidates,
                                                List<String> focusTags, int count,
                                                Integer difficulty) {
        if (candidates.isEmpty()) {
            return List.of();
        }
        List<PracticeQuestion> pool = new ArrayList<>(candidates);
        List<PracticeQuestion> picked = new ArrayList<>();
        Set<Long> used = new LinkedHashSet<>();
        Set<String> tags = focusTags == null ? Set.of() : new LinkedHashSet<>(focusTags);

        int[] ladder = difficulty != null ? new int[]{difficulty} : DEFAULT_LADDER;
        // 第一轮：薄弱点对应题按难度进阶
        if (!tags.isEmpty()) {
            for (int d : ladder) {
                for (PracticeQuestion q : pool) {
                    if (used.contains(q.getId())) continue;
                    if (tags.contains(q.getKnowledgeTag())
                            && Objects.equals(q.getDifficulty(), d)) {
                        picked.add(q);
                        used.add(q.getId());
                        if (picked.size() >= count) break;
                    }
                }
                if (picked.size() >= count) break;
            }
        }
        // 第二轮：通用补齐（同难度进阶）
        if (picked.size() < count) {
            for (int d : ladder) {
                for (PracticeQuestion q : pool) {
                    if (used.contains(q.getId())) continue;
                    if (Objects.equals(q.getDifficulty(), d)) {
                        picked.add(q);
                        used.add(q.getId());
                        if (picked.size() >= count) break;
                    }
                }
                if (picked.size() >= count) break;
            }
        }
        // 第三轮：还有余位则顺序补齐
        for (PracticeQuestion q : pool) {
            if (picked.size() >= count) break;
            if (used.contains(q.getId())) continue;
            picked.add(q);
            used.add(q.getId());
        }

        Map<Long, String> tbTitles = loadTextbookTitles(picked);
        return picked.stream().map(q -> toVO(q, tbTitles)).collect(Collectors.toList());
    }

    private List<PracticeQuestionVO> fillUp(List<PracticeQuestion> candidates,
                                            List<Long> selectedIds, int need) {
        Set<Long> used = new LinkedHashSet<>(selectedIds);
        List<PracticeQuestion> picked = new ArrayList<>();
        for (PracticeQuestion q : candidates) {
            if (picked.size() >= need) break;
            if (used.contains(q.getId())) continue;
            picked.add(q);
            used.add(q.getId());
        }
        Map<Long, String> tbTitles = loadTextbookTitles(picked);
        return picked.stream().map(q -> toVO(q, tbTitles)).collect(Collectors.toList());
    }

    private String buildRuleTitle(List<String> focusTags) {
        if (focusTags == null || focusTags.isEmpty()) {
            return "基础题自测卷";
        }
        return focusTags.get(0) + "专项自测卷";
    }

    private Map<Long, String> loadTextbookTitles(List<PracticeQuestion> questions) {
        List<Long> tbIds = questions.stream()
                .map(PracticeQuestion::getSourceTextbookId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        if (tbIds.isEmpty()) {
            return Collections.emptyMap();
        }
        return textbookMapper.selectList(
                        new LambdaQueryWrapper<Textbook>().in(Textbook::getId, tbIds))
                .stream()
                .collect(Collectors.toMap(Textbook::getId, Textbook::getTitle, (a, b) -> a));
    }

    private PracticeQuestionVO toVO(PracticeQuestion q, Map<Long, String> tbTitleMap) {
        return PracticeQuestionVO.builder()
                .id(q.getId())
                .questionType(q.getQuestionType())
                .department(q.getDepartment())
                .knowledgeTag(q.getKnowledgeTag())
                .title(q.getTitle())
                .options(parseOptions(q.getOptionsJson()))
                .answer(q.getAnswer())
                .explanation(q.getExplanation())
                .difficulty(q.getDifficulty())
                .sourceTextbookId(q.getSourceTextbookId())
                .sourceTextbookTitle(q.getSourceTextbookId() == null ? null
                        : tbTitleMap.get(q.getSourceTextbookId()))
                .build();
    }

    private List<String> parseOptions(String json) {
        if (!StringUtils.hasText(json)) {
            return Collections.emptyList();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {
            });
        } catch (Exception e) {
            log.warn("解析题目选项失败: {}", json, e);
            return Collections.emptyList();
        }
    }

    private String truncate(String s, int max) {
        if (s == null || s.length() <= max) {
            return s == null ? "" : s;
        }
        return s.substring(0, max);
    }
}
