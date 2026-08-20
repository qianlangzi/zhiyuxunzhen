package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
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

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
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
    private final AiPlatformClient aiPlatformClient;
    private final WeaknessAnalysisService weaknessAnalysisService;
    private final ObjectMapper objectMapper;

    /** AI 建议轻量缓存：key 由 学生→(tag+候选+错题) 决定，TTL 10 分钟，避免每次进 tab 都调 AI */
    private static final long ADVICE_CACHE_TTL_MS = 10 * 60 * 1000L;
    private final Map<String, AiCacheEntry> aiAdviceCache = new ConcurrentHashMap<>();

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