package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentItemProgress;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.DailyCaseSubmission;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.StudentPracticeRecord;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.DailyCaseSubmissionMapper;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.StudentPracticeRecordMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.StudentRecommendService;
import com.zhiyu.service.WeaknessAnalysisService;
import com.zhiyu.vo.CaseMarketListVO;
import com.zhiyu.vo.PracticeQuestionVO;
import com.zhiyu.vo.RecommendationVO;
import com.zhiyu.vo.SearchResultVO;
import com.zhiyu.vo.TextbookVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * 学生端智能检索服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentRecommendServiceImpl implements StudentRecommendService {

    private final StudentWeaknessMapper weaknessMapper;
    private final PracticeQuestionMapper questionMapper;
    private final TextbookMapper textbookMapper;
    private final SpCaseConfigMapper caseMapper;
    private final SysUserMapper userMapper;
    private final StudentMistakesMapper mistakesMapper;
    private final StudentPracticeRecordMapper practiceRecordMapper;
    private final AssignmentInstanceMapper assignmentInstanceMapper;
    private final AssignmentItemProgressMapper assignmentItemProgressMapper;
    private final ChatSessionMapper chatSessionMapper;
    private final DailyCaseSubmissionMapper dailyCaseSubmissionMapper;
    private final AiPlatformClient aiPlatformClient;
    private final WeaknessAnalysisService weaknessAnalysisService;
    private final ObjectMapper objectMapper;

    /** AI 建议轻量缓存：key 由 学生→(tag+候选+错题) 决定，TTL 10 分钟，避免每次进 tab 都调 AI */
    private static final long ADVICE_CACHE_TTL_MS = 10 * 60 * 1000L;
    private final Map<String, AiCacheEntry> aiAdviceCache = new ConcurrentHashMap<>();

    /** 学情画像快照（姓名 + 学习进度）轻量缓存：TTL 1 分钟，避免学伴每次对话都全表聚合 */
    private static final long PROFILE_CACHE_TTL_MS = 60 * 1000L;
    private final Map<Long, AiCacheEntry> profileCache = new ConcurrentHashMap<>();

    @Override
    public RecommendationVO recommendFor(String knowledgeTag) {
        if (!StringUtils.hasText(knowledgeTag)) {
            return RecommendationVO.builder()
                    .knowledgeTag("")
                    .questions(List.of())
                    .textbooks(List.of())
                    .build();
        }
        Long studentId = UserContext.requireUserId();
        List<PracticeQuestion> questions = queryQuestionsByTags(
                Collections.singletonList(knowledgeTag)).getOrDefault(knowledgeTag, List.of());
        List<Textbook> textbooks = queryTextbooksByTags(
                Collections.singletonList(knowledgeTag)).getOrDefault(knowledgeTag, List.of());
        List<String> mistakes = loadMistakesByTag(studentId, knowledgeTag);
        return buildRecommendation(knowledgeTag, questions, textbooks, mistakes);
    }

    @Override
    public List<RecommendationVO> recommendForAllWeaknesses() {
        Long studentId = UserContext.requireUserId();

        // 安全兜底：尚无薄弱数据时先重算，保证首次进入也能出结果（薄弱度推算闭环）
        List<StudentWeakness> weaknesses = loadWeaknesses(studentId);
        if (weaknesses.isEmpty()) {
            weaknessAnalysisService.refreshForStudent(studentId);
            weaknesses = loadWeaknesses(studentId);
        }
        if (weaknesses.isEmpty()) {
            return List.of();
        }

        // 批量加载，避免按知识点 N+1 查询
        List<String> tags = weaknesses.stream()
                .map(StudentWeakness::getKnowledgeTag)
                .filter(StringUtils::hasText)
                .distinct()
                .collect(Collectors.toList());
        Map<String, List<PracticeQuestion>> questionsByTag = queryQuestionsByTags(tags);
        Map<String, List<Textbook>> textbooksByTag = queryTextbooksByTags(tags);
        Map<String, List<String>> mistakesByTag = loadMistakesByTags(studentId, tags);

        List<RecommendationVO> result = new ArrayList<>();
        for (StudentWeakness w : weaknesses) {
            String tag = w.getKnowledgeTag();
            result.add(buildRecommendation(tag,
                    questionsByTag.getOrDefault(tag, List.of()),
                    textbooksByTag.getOrDefault(tag, List.of()),
                    mistakesByTag.getOrDefault(tag, List.of())));
        }
        return result;
    }

    @Override
    public SearchResultVO search(String keyword) {
        String kw = keyword == null ? "" : keyword.trim();
        if (kw.isEmpty()) {
            return SearchResultVO.builder()
                    .textbooks(List.of())
                    .questions(List.of())
                    .cases(List.of())
                    .build();
        }
        String like = "%" + kw + "%";

        // 教材
        List<Textbook> textbooks = textbookMapper.selectList(
                new LambdaQueryWrapper<Textbook>()
                        .eq(Textbook::getStatus, 1)
                        .and(w -> w.like(Textbook::getTitle, kw)
                                .or().like(Textbook::getAuthor, kw)
                                .or().like(Textbook::getKnowledgeTags, kw)));

        // 基础题
        List<PracticeQuestion> questions = questionMapper.selectList(
                new LambdaQueryWrapper<PracticeQuestion>()
                        .eq(PracticeQuestion::getStatus, 1)
                        .and(w -> w.like(PracticeQuestion::getTitle, kw)
                                .or().like(PracticeQuestion::getKnowledgeTag, kw)));

        // 病例
        List<SpCaseConfig> cases = caseMapper.selectList(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getIsPublic, true)
                        .eq(SpCaseConfig::getAdminAuditStatus, 2)
                        .eq(SpCaseConfig::getStatus, 1)
                        .and(w -> w.like(SpCaseConfig::getTitle, kw)
                                .or().like(SpCaseConfig::getDepartment, kw)
                                .or().like(SpCaseConfig::getKnowledgeTags, kw)));

        return SearchResultVO.builder()
                .textbooks(textbooks.stream().map(this::toTextbookVO).collect(Collectors.toList()))
                .questions(toQuestionVOs(questions))
                .cases(toCaseVOs(cases))
                .build();
    }

    @Override
    public Map<String, Object> buildLearningFacts() {
        Long studentId = UserContext.requireUserId();

        // 薄弱点（无则先重算，保证闭环）
        List<StudentWeakness> weaknesses = loadWeaknesses(studentId);
        if (weaknesses.isEmpty()) {
            weaknessAnalysisService.refreshForStudent(studentId);
            weaknesses = loadWeaknesses(studentId);
        }

        List<String> tags = weaknesses.stream()
                .map(StudentWeakness::getKnowledgeTag)
                .filter(StringUtils::hasText)
                .distinct()
                .limit(6)
                .collect(Collectors.toList());

        // 候选教材 / 基础题 / 病例（按薄弱点匹配，防幻觉）
        Map<String, List<Textbook>> textbooksByTag = tags.isEmpty() ? Map.of() : queryTextbooksByTags(tags);
        Map<String, List<PracticeQuestion>> questionsByTag = tags.isEmpty() ? Map.of() : queryQuestionsByTags(tags);
        List<Textbook> candidateTextbooks = textbooksByTag.values().stream()
                .flatMap(List::stream).distinct().collect(Collectors.toList());
        List<PracticeQuestion> candidateQuestions = questionsByTag.values().stream()
                .flatMap(List::stream).distinct().collect(Collectors.toList());
        List<SpCaseConfig> candidateCases = tags.isEmpty() ? List.of() : queryCasesByTags(tags);

        // 近期错题要点
        Map<String, List<String>> mistakesByTag = tags.isEmpty() ? Map.of() : loadMistakesByTags(studentId, tags);

        Map<String, Object> facts = new HashMap<>();
        facts.put("weaknesses", weaknesses.stream()
                .filter(w -> StringUtils.hasText(w.getKnowledgeTag()))
                .limit(6)
                .map(w -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("knowledgeTag", w.getKnowledgeTag());
                    m.put("weaknessScore", w.getWeaknessScore() == null ? null : w.getWeaknessScore().doubleValue());
                    // 与 AI 中台 format_student_context 对齐：AI 侧读取 mastery（0~1 掌握度，越高越扎实）
                    Double weaknessScore = w.getWeaknessScore() == null ? null : w.getWeaknessScore().doubleValue();
                    m.put("mastery", weaknessScore == null ? null
                            : Math.round(weaknessScore * 100.0) / 100.0);
                    m.put("evidenceCount", w.getEvidenceCount());
                    return m;
                })
                .collect(Collectors.toList()));
        facts.put("mistakes", mistakesByTag.entrySet().stream()
                .flatMap(e -> e.getValue().stream().map(note -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("knowledgeTag", e.getKey());
                    m.put("note", note);
                    return m;
                }))
                .limit(12)
                .collect(Collectors.toList()));
        facts.put("learnedChapters", List.of());
        facts.put("candidateTextbooks", candidateTextbooks.stream()
                .map(t -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", t.getId());
                    m.put("title", t.getTitle());
                    return m;
                })
                .collect(Collectors.toList()));
        facts.put("candidateQuestions", candidateQuestions.stream()
                .map(q -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", q.getId());
                    m.put("title", q.getTitle());
                    m.put("difficulty", q.getDifficulty());
                    return m;
                })
                .collect(Collectors.toList()));
        facts.put("candidateCases", candidateCases.stream()
                .map(c -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id", c.getId());
                    m.put("title", c.getTitle());
                    m.put("difficulty", c.getDifficulty());
                    return m;
                })
                .collect(Collectors.toList()));

        // 学生基础画像（姓名/年级/学校）+ 学习进度（累计学习天数/刷题/作业/问诊/每日一例/阅读章节）
        // 供 AI 学伴等个性化 Agent 感知"正在跟谁对话、学到了哪一步"，避免"瞎聊"。
        Map<String, Object> snapshot = buildProfileSnapshot(studentId);
        facts.put("student", snapshot.get("student"));
        facts.put("progress", snapshot.get("progress"));
        return facts;
    }

    /** 组装学生画像与学习进度快照（带 1 分钟 TTL 缓存，避免每次对话全表聚合） */
    private Map<String, Object> buildProfileSnapshot(Long studentId) {
        AiCacheEntry hit = profileCache.get(studentId);
        if (hit != null && (System.currentTimeMillis() - hit.timestamp) < PROFILE_CACHE_TTL_MS) {
            return hit.value;
        }
        Map<String, Object> snapshot = new HashMap<>();
        // ---- 学生基础信息（姓名/学校/年级），无则匿名兜底 ----
        Map<String, Object> student = new HashMap<>();
        try {
            SysUser user = userMapper.selectById(studentId);
            if (user != null) {
                String name = StringUtils.hasText(user.getRealName()) ? user.getRealName() : user.getUsername();
                student.put("realName", name);
                student.put("username", user.getUsername());
                if (StringUtils.hasText(user.getSchoolName())) student.put("schoolName", user.getSchoolName());
                if (StringUtils.hasText(user.getGrade())) student.put("grade", user.getGrade());
                if (StringUtils.hasText(user.getClassName())) student.put("className", user.getClassName());
                if (user.getRole() != null) student.put("role", user.getRole());
            }
        } catch (Exception e) {
            log.warn("学伴画像-读取学生基础信息失败 studentId={}: {}", studentId, e.getMessage());
        }
        snapshot.put("student", student);

        // ---- 学习进度聚合 ----
        List<Map<String, Object>> progress = new ArrayList<>();
        LocalDateTime since = LocalDate.now().minusDays(180).atStartOfDay();
        try {
            Long practiceCount = practiceRecordMapper.selectCount(
                    new LambdaQueryWrapper<StudentPracticeRecord>()
                            .eq(StudentPracticeRecord::getStudentId, studentId));
            if (practiceCount != null && practiceCount > 0) {
                Map<String, Object> item = new HashMap<>();
                item.put("label", "已刷基础题");
                item.put("value", practiceCount + " 题");
                progress.add(item);
            }

            Long assignmentDone = assignmentInstanceMapper.selectCount(
                    new LambdaQueryWrapper<AssignmentInstance>()
                            .eq(AssignmentInstance::getStudentId, studentId)
                            // 3=单病例提交通过 5=组合包全部任务完成（见 StudentAssignmentServiceImpl 状态流转）
                            .in(AssignmentInstance::getStatus, 3, 5));
            if (assignmentDone != null && assignmentDone > 0) {
                Map<String, Object> item = new HashMap<>();
                item.put("label", "已完成作业");
                item.put("value", assignmentDone + " 个");
                progress.add(item);
            }

            Long sessionDone = chatSessionMapper.selectCount(
                    new LambdaQueryWrapper<ChatSession>()
                            .eq(ChatSession::getStudentId, studentId)
                            .eq(ChatSession::getStatus, 1)); // 1=已结束的问诊会话
            if (sessionDone != null && sessionDone > 0) {
                Map<String, Object> item = new HashMap<>();
                item.put("label", "完成问诊训练");
                item.put("value", sessionDone + " 次");
                progress.add(item);
            }

            Long dailyCases = dailyCaseSubmissionMapper.selectCount(
                    new LambdaQueryWrapper<DailyCaseSubmission>()
                            .eq(DailyCaseSubmission::getStudentId, studentId));
            if (dailyCases != null && dailyCases > 0) {
                Map<String, Object> item = new HashMap<>();
                item.put("label", "完成每日一例");
                item.put("value", dailyCases + " 次");
                progress.add(item);
            }

            // 阅读任务（教材章节）：assignment_item_progress 有 completed_at 且对应 item_type='READING'
            Long readChapters = assignmentItemProgressMapper.selectCount(
                    new LambdaQueryWrapper<AssignmentItemProgress>()
                            .eq(AssignmentItemProgress::getStudentId, studentId)
                            .isNotNull(AssignmentItemProgress::getCompletedAt)
                            .inSql(AssignmentItemProgress::getItemId,
                                    "SELECT id FROM assignment_item WHERE item_type='READING' "
                                            + "AND (is_deleted IS NULL OR is_deleted=0)"));
            if (readChapters != null && readChapters > 0) {
                Map<String, Object> item = new HashMap<>();
                item.put("label", "读完教材章节");
                item.put("value", readChapters + " 章");
                progress.add(item);
            }

            // 累计学习天数：近 180 天有刷题/问诊/每日一例任一活动的自然日数
            long activeDays = countActiveDays(studentId, since);
            if (activeDays > 0) {
                Map<String, Object> item = new HashMap<>();
                item.put("label", "已坚持学习");
                item.put("value", activeDays + " 天");
                progress.add(item);
            }
        } catch (Exception e) {
            log.warn("学伴画像-学习进度聚合失败 studentId={}: {}", studentId, e.getMessage());
        }
        snapshot.put("progress", progress);
        profileCache.put(studentId, new AiCacheEntry(snapshot, System.currentTimeMillis()));
        return snapshot;
    }

    /** 统计近 since 起该学生在刷题/问诊/每日一例中出现过的自然日数 */
    private long countActiveDays(Long studentId, LocalDateTime since) {
        Set<LocalDate> days = new LinkedHashSet<>();
        List<StudentPracticeRecord> practices = practiceRecordMapper.selectList(
                new LambdaQueryWrapper<StudentPracticeRecord>()
                        .select(StudentPracticeRecord::getAnsweredAt)
                        .eq(StudentPracticeRecord::getStudentId, studentId)
                        .ge(StudentPracticeRecord::getAnsweredAt, since));
        practices.forEach(p -> {
            if (p.getAnsweredAt() != null) days.add(p.getAnsweredAt().toLocalDate());
        });
        List<ChatSession> sessions = chatSessionMapper.selectList(
                new LambdaQueryWrapper<ChatSession>()
                        .select(ChatSession::getCreatedAt)
                        .eq(ChatSession::getStudentId, studentId)
                        .ge(ChatSession::getCreatedAt, since));
        sessions.forEach(s -> {
            if (s.getCreatedAt() != null) days.add(s.getCreatedAt().toLocalDate());
        });
        List<DailyCaseSubmission> submissions = dailyCaseSubmissionMapper.selectList(
                new LambdaQueryWrapper<DailyCaseSubmission>()
                        .select(DailyCaseSubmission::getSubmittedAt)
                        .eq(DailyCaseSubmission::getStudentId, studentId)
                        .ge(DailyCaseSubmission::getSubmittedAt, since));
        submissions.forEach(s -> {
            if (s.getSubmittedAt() != null) days.add(s.getSubmittedAt().toLocalDate());
        });
        return days.size();
    }

    /** AI 学情诊断轻量缓存：TTL 10 分钟，避免每次进推荐页都调 AI */
    private final Map<String, AiCacheEntry> diagnosisCache = new ConcurrentHashMap<>();

    @Override
    public Map<String, Object> aiDiagnosis() {
        Long studentId = UserContext.requireUserId();

        // 统计兜底：尚无薄弱数据时先重算，保证闭环
        List<StudentWeakness> weaknesses = loadWeaknesses(studentId);
        if (weaknesses.isEmpty()) {
            weaknessAnalysisService.refreshForStudent(studentId);
            weaknesses = loadWeaknesses(studentId);
        }
        if (weaknesses.isEmpty()) {
            Map<String, Object> empty = new HashMap<>();
            empty.put("overall", "");
            empty.put("items", List.of());
            empty.put("source", "STAT");
            empty.put("status", "SUCCESS");
            return empty;
        }

        List<String> tags = weaknesses.stream()
                .map(StudentWeakness::getKnowledgeTag)
                .filter(StringUtils::hasText)
                .distinct()
                .limit(10)
                .collect(Collectors.toList());
        Map<String, List<String>> mistakesByTag = tags.isEmpty() ? Map.of() : loadMistakesByTags(studentId, tags);

        // 缓存命中（基于学生 + 薄弱快照签名）
        String cacheKey = studentId + "::" + weaknesses.stream()
                .map(w -> w.getKnowledgeTag() + ":" + w.getWeaknessScore())
                .sorted().collect(Collectors.joining("|"));
        AiCacheEntry hit = diagnosisCache.get(cacheKey);
        if (hit != null && (System.currentTimeMillis() - hit.timestamp) < ADVICE_CACHE_TTL_MS) {
            return hit.value;
        }

        // STAT 快照
        List<Map<String, Object>> statWeaknesses = weaknesses.stream()
                .filter(w -> StringUtils.hasText(w.getKnowledgeTag()))
                .map(w -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("knowledgeTag", w.getKnowledgeTag());
                    m.put("weaknessScore", w.getWeaknessScore() == null ? null : w.getWeaknessScore().doubleValue());
                    m.put("evidenceCount", w.getEvidenceCount());
                    return m;
                })
                .collect(Collectors.toList());
        List<Map<String, Object>> mistakes = mistakesByTag.entrySet().stream()
                .flatMap(e -> e.getValue().stream().map(note -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("knowledgeTag", e.getKey());
                    m.put("note", note);
                    return m;
                }))
                .limit(12)
                .collect(Collectors.toList());

        Map<String, Object> ai = aiPlatformClient.weaknessDiagnosis(studentId, statWeaknesses, mistakes);

        // 合并 STAT + AI
        Map<String, Object> result = new HashMap<>();
        boolean degraded = ai == null || !"SUCCESS".equals(ai.get("status"));
        result.put("source", degraded ? "STAT" : "AI");
        result.put("status", degraded ? "DEGRADED" : "SUCCESS");
        result.put("overall", degraded
                ? (ai != null && ai.get("overall") != null
                        ? String.valueOf(ai.get("overall")) : "AI 学情诊断暂时不可用，当前展示统计薄弱点。")
                : String.valueOf(ai.getOrDefault("overall", "")));

        // AI items 索引
        Map<String, Map<String, Object>> aiByTag = new HashMap<>();
        if (ai != null && ai.get("items") instanceof List<?> aiItems) {
            for (Object it : aiItems) {
                if (it instanceof Map<?, ?> im) {
                    Object tagObj = im.get("knowledgeTag");
                    if (tagObj == null) continue;
                    String tag = String.valueOf(tagObj);
                    if (!tag.isBlank()) {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> cast = (Map<String, Object>) im;
                        aiByTag.put(tag, cast);
                    }
                }
            }
        }

        List<Map<String, Object>> items = new ArrayList<>();
        for (StudentWeakness w : weaknesses) {
            String tag = w.getKnowledgeTag();
            if (!StringUtils.hasText(tag)) continue;
            Map<String, Object> item = new HashMap<>();
            item.put("knowledgeTag", tag);
            item.put("statScore", w.getWeaknessScore() == null ? null : w.getWeaknessScore().doubleValue());
            item.put("evidenceCount", w.getEvidenceCount());
            Map<String, Object> aiItem = aiByTag.get(tag);
            item.put("rootCause", aiItem != null ? String.valueOf(aiItem.getOrDefault("rootCause", "")) : "");
            item.put("suggestion", aiItem != null ? String.valueOf(aiItem.getOrDefault("suggestion", "")) : "");
            item.put("source", aiItem != null ? "STAT+AI" : "STAT");
            items.add(item);
        }
        result.put("items", items);
        diagnosisCache.put(cacheKey, new AiCacheEntry(result, System.currentTimeMillis()));
        return result;
    }

    /** 按薄弱知识点批量查上架且审核通过的病例（防幻觉候选） */
    private List<SpCaseConfig> queryCasesByTags(List<String> tags) {
        if (tags == null || tags.isEmpty()) {
            return List.of();
        }
        List<SpCaseConfig> all = caseMapper.selectList(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getIsPublic, true)
                        .eq(SpCaseConfig::getAdminAuditStatus, 2)
                        .eq(SpCaseConfig::getStatus, 1));
        Set<String> wanted = new HashSet<>(tags);
        return all.stream()
                .filter(c -> {
                    List<String> cTags = parseTags(c.getKnowledgeTags());
                    return cTags.stream().anyMatch(wanted::contains);
                })
                .collect(Collectors.toList());
    }

    // ---------- 私有辅助 ----------

    private List<StudentWeakness> loadWeaknesses(Long studentId) {
        return weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, studentId)
                        .orderByAsc(StudentWeakness::getWeaknessScore)   // 越薄弱越靠前
                        .orderByDesc(StudentWeakness::getEvidenceCount)); // 同分则证据更充分者优先
    }

    /** 批量按知识点查上架基础题（按难度升序），避免 N+1 */
    private Map<String, List<PracticeQuestion>> queryQuestionsByTags(List<String> tags) {
        Map<String, List<PracticeQuestion>> map = new HashMap<>();
        if (tags == null || tags.isEmpty()) {
            return map;
        }
        List<PracticeQuestion> list = questionMapper.selectList(
                new LambdaQueryWrapper<PracticeQuestion>()
                        .eq(PracticeQuestion::getStatus, 1)
                        .in(PracticeQuestion::getKnowledgeTag, tags)
                        .orderByAsc(PracticeQuestion::getDifficulty));
        for (PracticeQuestion q : list) {
            if (StringUtils.hasText(q.getKnowledgeTag())) {
                map.computeIfAbsent(q.getKnowledgeTag(), k -> new ArrayList<>()).add(q);
            }
        }
        return map;
    }

    /** 批量按知识点查教材（教材 knowledgeTags 为 JSON 数组，需解析后匹配） */
    private Map<String, List<Textbook>> queryTextbooksByTags(List<String> tags) {
        Map<String, List<Textbook>> map = new HashMap<>();
        if (tags == null || tags.isEmpty()) {
            return map;
        }
        Set<String> wanted = new HashSet<>(tags);
        List<Textbook> all = textbookMapper.selectList(
                new LambdaQueryWrapper<Textbook>().eq(Textbook::getStatus, 1));
        for (Textbook tb : all) {
            for (String t : parseTags(tb.getKnowledgeTags())) {
                if (wanted.contains(t)) {
                    map.computeIfAbsent(t, k -> new ArrayList<>()).add(tb);
                }
            }
        }
        return map;
    }

    /** 批量拉取各薄弱知识点近期错题要点（每个知识点最多 5 条），作为 AI 输入 */
    private Map<String, List<String>> loadMistakesByTags(Long studentId, List<String> tags) {
        Map<String, List<String>> map = new HashMap<>();
        if (tags == null || tags.isEmpty()) {
            return map;
        }
        List<StudentMistakes> recent = mistakesMapper.selectList(
                new LambdaQueryWrapper<StudentMistakes>()
                        .eq(StudentMistakes::getStudentId, studentId)
                        .in(StudentMistakes::getKnowledgeTag, tags)
                        .orderByDesc(StudentMistakes::getCreatedAt));
        for (StudentMistakes m : recent) {
            String tag = m.getKnowledgeTag();
            if (!StringUtils.hasText(tag)) {
                continue;
            }
            String note = StringUtils.hasText(m.getEvidenceJson()) ? m.getEvidenceJson()
                    : (StringUtils.hasText(m.getStudentAnswer()) ? "学生作答：" + m.getStudentAnswer() : null);
            if (note == null) {
                continue;
            }
            List<String> bucket = map.computeIfAbsent(tag, k -> new ArrayList<>());
            if (bucket.size() < 5) {
                bucket.add(note);
            }
        }
        return map;
    }

    private List<String> loadMistakesByTag(Long studentId, String tag) {
        return loadMistakesByTags(studentId, Collections.singletonList(tag))
                .getOrDefault(tag, List.of());
    }

    /** 组装单个知识点的推荐：基础题 + 教材 + AI 补救建议（带 grounding 与缓存） */
    private RecommendationVO buildRecommendation(String tag, List<PracticeQuestion> questions,
                                                 List<Textbook> textbooks, List<String> mistakes) {
        Map<String, Object> aiResult = aiAdvice(tag, mistakes, textbooks, questions);
        return RecommendationVO.builder()
                .knowledgeTag(tag)
                .questions(toQuestionVOs(questions))
                .textbooks(textbooks.stream().map(this::toTextbookVO).collect(Collectors.toList()))
                .aiAdvice(aiResult == null ? null : str(aiResult.get("advice")))
                .aiPriority(aiResult == null ? null : strList(aiResult.get("priority")))
                .aiStudyPlan(aiResult == null ? null : str(aiResult.get("studyPlan")))
                .aiMistakesNote(aiResult == null ? null : str(aiResult.get("mistakesNote")))
                .build();
    }

    /** 生成 AI 补救建议：候选教材/题目标题传给 LLM 防幻觉；结果按 key 缓存 10 分钟 */
    private Map<String, Object> aiAdvice(String tag, List<String> mistakes,
                                         List<Textbook> textbooks, List<PracticeQuestion> questions) {
        String key = adviceCacheKey(tag, mistakes, textbooks, questions);
        AiCacheEntry cached = aiAdviceCache.get(key);
        if (cached != null && (System.currentTimeMillis() - cached.timestamp) < ADVICE_CACHE_TTL_MS) {
            return cached.value;
        }
        List<String> candidateBooks = textbooks.stream().map(Textbook::getTitle)
                .filter(StringUtils::hasText).collect(Collectors.toList());
        List<String> candidateQuestions = questions.stream().map(PracticeQuestion::getTitle)
                .filter(StringUtils::hasText).collect(Collectors.toList());
        Map<String, Object> result = aiPlatformClient.recommendWeakness(
                Collections.singletonList(tag), mistakes, candidateBooks, candidateQuestions);
        aiAdviceCache.put(key, new AiCacheEntry(result, System.currentTimeMillis()));
        return result;
    }

    private String adviceCacheKey(String tag, List<String> mistakes,
                                  List<Textbook> textbooks, List<PracticeQuestion> questions) {
        String books = textbooks.stream().map(t -> String.valueOf(t.getId())).sorted().collect(Collectors.joining(","));
        String qs = questions.stream().map(q -> String.valueOf(q.getId())).sorted().collect(Collectors.joining(","));
        return tag + "::" + books + "::" + qs + "::" + String.join("|", mistakes);
    }

    private static class AiCacheEntry {
        final Map<String, Object> value;
        final long timestamp;

        AiCacheEntry(Map<String, Object> value, long timestamp) {
            this.value = value;
            this.timestamp = timestamp;
        }
    }

    private List<PracticeQuestionVO> toQuestionVOs(List<PracticeQuestion> questions) {
        return questions.stream()
                .map(q -> PracticeQuestionVO.builder()
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
                        .build())
                .collect(Collectors.toList());
    }

    private TextbookVO toTextbookVO(Textbook tb) {
        return TextbookVO.builder()
                .id(tb.getId())
                .title(tb.getTitle())
                .edition(tb.getEdition())
                .department(tb.getDepartment())
                .author(tb.getAuthor())
                .publisher(tb.getPublisher())
                .coverUrl(tb.getCoverUrl())
                .fileUrl(tb.getFileUrl())
                .description(tb.getDescription())
                .knowledgeTags(parseTags(tb.getKnowledgeTags()))
                .chapterCount(tb.getChapterCount())
                .pageCount(tb.getPageCount())
                .build();
    }

    private List<CaseMarketListVO> toCaseVOs(List<SpCaseConfig> cases) {
        List<Long> creatorIds = cases.stream()
                .map(SpCaseConfig::getCreatorId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, String> nameMap = new HashMap<>();
        if (!creatorIds.isEmpty()) {
            for (SysUser u : userMapper.selectList(
                    new LambdaQueryWrapper<SysUser>().in(SysUser::getId, creatorIds))) {
                nameMap.put(u.getId(), u.getRealName());
            }
        }
        return cases.stream().map(c -> CaseMarketListVO.builder()
                .id(c.getId())
                .title(c.getTitle())
                .department(c.getDepartment())
                .difficulty(c.getDifficulty())
                .ratingAvg(c.getRatingAvg())
                .referenceCount(c.getReferenceCount())
                .creatorName(nameMap.getOrDefault(c.getCreatorId(), ""))
                .knowledgeTags(c.getKnowledgeTags())
                .createdAt(c.getCreatedAt())
                .build()).collect(Collectors.toList());
    }

    private List<String> parseTags(String json) {
        if (!StringUtils.hasText(json)) {
            return List.of();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {
            });
        } catch (Exception e) {
            log.warn("解析知识点失败: {}", json, e);
            return List.of();
        }
    }

    private String str(Object obj) {
        return obj == null ? null : obj.toString();
    }

    @SuppressWarnings("unchecked")
    private List<String> strList(Object obj) {
        if (obj instanceof List<?> list) {
            List<String> result = new ArrayList<>();
            for (Object item : list) {
                if (item != null) result.add(item.toString());
            }
            return result;
        }
        return null;
    }

    private List<String> parseOptions(String json) {
        if (!StringUtils.hasText(json)) {
            return List.of();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {
            });
        } catch (Exception e) {
            log.warn("解析题目选项失败: {}", json, e);
            return List.of();
        }
    }
}