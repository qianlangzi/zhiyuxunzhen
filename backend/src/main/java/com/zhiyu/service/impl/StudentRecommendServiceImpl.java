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
    private final ObjectMapper objectMapper;

    @Override
    public RecommendationVO recommendFor(String knowledgeTag) {
        if (!StringUtils.hasText(knowledgeTag)) {
            return RecommendationVO.builder()
                    .knowledgeTag("")
                    .questions(List.of())
                    .textbooks(List.of())
                    .build();
        }
        List<PracticeQuestion> questions = questionMapper.selectList(
                new LambdaQueryWrapper<PracticeQuestion>()
                        .eq(PracticeQuestion::getStatus, 1)
                        .eq(PracticeQuestion::getKnowledgeTag, knowledgeTag)
                        .orderByAsc(PracticeQuestion::getDifficulty));
        List<Textbook> textbooks = findTextbooksByTag(knowledgeTag);

        // 拉取该知识点下近期错题要点，作为 AI 智能推荐的输入（无则传空列表）
        List<String> mistakeNotes = new ArrayList<>();
        try {
            Long studentId = UserContext.requireUserId();
            List<StudentMistakes> recent = mistakesMapper.selectList(
                    new LambdaQueryWrapper<StudentMistakes>()
                            .eq(StudentMistakes::getStudentId, studentId)
                            .eq(StudentMistakes::getKnowledgeTag, knowledgeTag)
                            .orderByDesc(StudentMistakes::getCreatedAt)
                            .last("LIMIT 5"));
            for (StudentMistakes m : recent) {
                if (StringUtils.hasText(m.getEvidenceJson())) {
                    mistakeNotes.add(m.getEvidenceJson());
                } else if (StringUtils.hasText(m.getStudentAnswer())) {
                    mistakeNotes.add("学生作答：" + m.getStudentAnswer());
                }
            }
        } catch (Exception e) {
            log.warn("查询近期错题失败，AI 建议降级为空: tag={} error={}", knowledgeTag, e.getMessage());
        }

        // 调用 AI 平台生成个性化补救建议（失败返回 null，不阻断错题板块）
        Map<String, Object> aiResult = aiPlatformClient.recommendWeakness(
                Collections.singletonList(knowledgeTag), mistakeNotes);

        return RecommendationVO.builder()
                .knowledgeTag(knowledgeTag)
                .questions(toQuestionVOs(questions))
                .textbooks(textbooks.stream().map(this::toTextbookVO).collect(Collectors.toList()))
                .aiAdvice(aiResult == null ? null : str(aiResult.get("advice")))
                .aiPriority(aiResult == null ? null : strList(aiResult.get("priority")))
                .aiStudyPlan(aiResult == null ? null : str(aiResult.get("studyPlan")))
                .aiMistakesNote(aiResult == null ? null : str(aiResult.get("mistakesNote")))
                .build();
    }

    @Override
    public List<RecommendationVO> recommendForAllWeaknesses() {
        Long studentId = UserContext.requireUserId();
        List<StudentWeakness> weaknesses = weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, studentId)
                        .orderByAsc(StudentWeakness::getWeaknessScore));
        List<RecommendationVO> result = new ArrayList<>();
        for (StudentWeakness w : weaknesses) {
            result.add(recommendFor(w.getKnowledgeTag()));
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

    private List<Textbook> findTextbooksByTag(String tag) {
        List<Textbook> all = textbookMapper.selectList(
                new LambdaQueryWrapper<Textbook>().eq(Textbook::getStatus, 1));
        return all.stream().filter(tb -> parseTags(tb.getKnowledgeTags()).contains(tag))
                .collect(Collectors.toList());
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