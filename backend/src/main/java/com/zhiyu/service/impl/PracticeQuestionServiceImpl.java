package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.StudentPracticeRecord;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.StudentPracticeRecordMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.PracticeQuestionService;
import com.zhiyu.service.WeaknessAnalysisService;
import com.zhiyu.service.dto.PracticeAnswerDTO;
import com.zhiyu.vo.PracticeQuestionVO;
import com.zhiyu.vo.PracticeStatsVO;
import com.zhiyu.vo.SubmitResultVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 基础题训练服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PracticeQuestionServiceImpl implements PracticeQuestionService {

    private final PracticeQuestionMapper questionMapper;
    private final StudentPracticeRecordMapper recordMapper;
    private final TextbookMapper textbookMapper;
    private final ObjectMapper objectMapper;
    private final WeaknessAnalysisService weaknessAnalysisService;

    @Override
    public PageResult<PracticeQuestionVO> page(Integer pageNum, Integer pageSize,
                                               String department, String knowledgeTag,
                                               Integer difficulty, String questionType) {
        Page<PracticeQuestion> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<PracticeQuestion> wrapper = new LambdaQueryWrapper<PracticeQuestion>()
                .eq(PracticeQuestion::getStatus, 1)
                .eq(StringUtils.hasText(department), PracticeQuestion::getDepartment, department)
                .eq(StringUtils.hasText(knowledgeTag), PracticeQuestion::getKnowledgeTag, knowledgeTag)
                .eq(difficulty != null, PracticeQuestion::getDifficulty, difficulty)
                .eq(StringUtils.hasText(questionType), PracticeQuestion::getQuestionType, questionType)
                .orderByAsc(PracticeQuestion::getDepartment)
                .orderByAsc(PracticeQuestion::getDifficulty)
                .orderByDesc(PracticeQuestion::getCreatedAt);
        questionMapper.selectPage(page, wrapper);

        Map<Long, String> tbTitleMap = loadTextbookTitles(page.getRecords());
        List<PracticeQuestionVO> list = page.getRecords().stream()
                .map(q -> toVO(q, tbTitleMap))
                .collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public PageResult<PracticeQuestionVO> pageByDepartment(Integer pageNum, Integer pageSize,
                                                           String department, Integer difficulty) {
        Page<PracticeQuestion> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<PracticeQuestion> wrapper = new LambdaQueryWrapper<PracticeQuestion>()
                .eq(PracticeQuestion::getStatus, 1)
                .eq(StringUtils.hasText(department), PracticeQuestion::getDepartment, department)
                .ge(difficulty != null, PracticeQuestion::getDifficulty, difficulty)
                .orderByAsc(PracticeQuestion::getDifficulty)
                .orderByAsc(PracticeQuestion::getId);
        questionMapper.selectPage(page, wrapper);

        Map<Long, String> tbTitleMap = loadTextbookTitles(page.getRecords());
        List<PracticeQuestionVO> list = page.getRecords().stream()
                .map(q -> toVO(q, tbTitleMap))
                .collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public List<String> departments() {
        return questionMapper.selectList(
                        new LambdaQueryWrapper<PracticeQuestion>()
                                .eq(PracticeQuestion::getStatus, 1)
                                .isNotNull(PracticeQuestion::getDepartment)
                                .groupBy(PracticeQuestion::getDepartment)
                                .select(PracticeQuestion::getDepartment))
                .stream()
                .map(PracticeQuestion::getDepartment)
                .filter(StringUtils::hasText)
                .collect(Collectors.toList());
    }

    @Override
    public List<String> knowledgeTags() {
        return questionMapper.selectList(
                        new LambdaQueryWrapper<PracticeQuestion>()
                                .eq(PracticeQuestion::getStatus, 1)
                                .isNotNull(PracticeQuestion::getKnowledgeTag)
                                .groupBy(PracticeQuestion::getKnowledgeTag)
                                .select(PracticeQuestion::getKnowledgeTag))
                .stream()
                .map(PracticeQuestion::getKnowledgeTag)
                .filter(StringUtils::hasText)
                .collect(Collectors.toList());
    }

    @Override
    public PracticeQuestionVO detail(Long id) {
        PracticeQuestion q = questionMapper.selectById(id);
        if (q == null || q.getStatus() == 0) {
            throw new BizException(ResultCode.NOT_FOUND, "题目不存在或已下架");
        }
        return toVO(q, loadTextbookTitles(Collections.singletonList(q)));
    }

    @Override
    public SubmitResultVO submit(PracticeAnswerDTO dto) {
        Long studentId = UserContext.requireUserId();
        PracticeQuestion q = questionMapper.selectById(dto.getQuestionId());
        if (q == null || q.getStatus() == 0) {
            throw new BizException(ResultCode.NOT_FOUND, "题目不存在或已下架");
        }
        boolean correct = judgeAnswer(q, dto.getSelectedAnswer());

        StudentPracticeRecord record = new StudentPracticeRecord();
        record.setStudentId(studentId);
        record.setQuestionId(q.getId());
        record.setSelectedAnswer(dto.getSelectedAnswer());
        record.setIsCorrect(correct);
        record.setAnsweredAt(LocalDateTime.now());
        recordMapper.insert(record);

        // 刷题作答入库后立即重算该学生的薄弱知识点掌握度（薄弱度推算闭环）
        try {
            weaknessAnalysisService.refreshForStudent(studentId);
        } catch (Exception e) {
            log.warn("刷题后薄弱点重算失败，不影响判题: studentId={} error={}", studentId, e.getMessage());
        }

        return SubmitResultVO.builder()
                .questionId(q.getId())
                .isCorrect(correct)
                .selectedAnswer(dto.getSelectedAnswer())
                .correctAnswer(q.getAnswer())
                .explanation(q.getExplanation())
                .build();
    }

    /**
     * 按题型判题：
     * - multiple_choice：多选，选项下标逗号分隔，忽略顺序比较
     * - fill_blank：填空，忽略首尾空白与大小写后比较
     * - 其余（single_choice/judgment）：字符串精确比较
     */
    private boolean judgeAnswer(PracticeQuestion q, String selected) {
        if (selected == null) {
            return false;
        }
        String type = q.getQuestionType();
        String correct = q.getAnswer() == null ? "" : q.getAnswer();
        if ("multiple_choice".equalsIgnoreCase(type)) {
            Set<String> selectedSet = Arrays.stream(selected.split(","))
                    .map(String::trim).filter(s -> !s.isEmpty()).collect(Collectors.toSet());
            Set<String> correctSet = Arrays.stream(correct.split(","))
                    .map(String::trim).filter(s -> !s.isEmpty()).collect(Collectors.toSet());
            return selectedSet.equals(correctSet);
        }
        if ("fill_blank".equalsIgnoreCase(type)) {
            return normalizeBlank(selected).equals(normalizeBlank(correct));
        }
        return Objects.equals(correct, selected);
    }

    private String normalizeBlank(String s) {
        return s.trim().replaceAll("\\s+", "").toLowerCase();
    }

    @Override
    public PracticeStatsVO stats() {
        Long studentId = UserContext.requireUserId();

        long totalCount = questionMapper.selectCount(
                new LambdaQueryWrapper<PracticeQuestion>().eq(PracticeQuestion::getStatus, 1));

        List<StudentPracticeRecord> records = recordMapper.selectList(
                new LambdaQueryWrapper<StudentPracticeRecord>()
                        .eq(StudentPracticeRecord::getStudentId, studentId));

        long totalAnswered = records.size();
        long correctCount = records.stream().filter(r -> Boolean.TRUE.equals(r.getIsCorrect())).count();

        // 按知识点聚合
        Map<String, PracticeStatsVO.ByKnowledgeTag> byTag = new LinkedHashMap<>();
        practiceTagCounts(byTag); // 题库各知识点总量
        // 按科室（模块）聚合
        Map<String, PracticeStatsVO.ByDepartment> byDept = new LinkedHashMap<>();
        practiceDeptCounts(byDept); // 题库各科室总量

        for (StudentPracticeRecord r : records) {
            PracticeQuestion q = questionMapper.selectById(r.getQuestionId());
            if (q == null) {
                continue;
            }
            boolean correct = Boolean.TRUE.equals(r.getIsCorrect());
            if (q.getKnowledgeTag() != null) {
                PracticeStatsVO.ByKnowledgeTag entry = byTag.computeIfAbsent(q.getKnowledgeTag(),
                        k -> PracticeStatsVO.ByKnowledgeTag.builder().knowledgeTag(k).build());
                entry.setAnswered(entry.getAnswered() + 1);
                if (correct) {
                    entry.setCorrect(entry.getCorrect() + 1);
                }
                entry.setAccuracy(entry.getAnswered() == 0 ? 0.0
                        : (double) entry.getCorrect() / entry.getAnswered());
            }
            if (q.getDepartment() != null) {
                PracticeStatsVO.ByDepartment dept = byDept.computeIfAbsent(q.getDepartment(),
                        d -> PracticeStatsVO.ByDepartment.builder().department(d).build());
                dept.setAnswered(dept.getAnswered() + 1);
                if (correct) {
                    dept.setCorrect(dept.getCorrect() + 1);
                }
                dept.setAccuracy(dept.getAnswered() == 0 ? 0.0
                        : (double) dept.getCorrect() / dept.getAnswered());
            }
        }

        return PracticeStatsVO.builder()
                .totalCount(totalCount)
                .totalAnswered(totalAnswered)
                .correctCount(correctCount)
                .accuracy(totalAnswered == 0 ? 0.0 : (double) correctCount / totalAnswered)
                .byKnowledgeTag(new ArrayList<>(byTag.values()))
                .byDepartment(new ArrayList<>(byDept.values()))
                .build();
    }

    private void practiceTagCounts(Map<String, PracticeStatsVO.ByKnowledgeTag> byTag) {
        List<PracticeQuestion> all = questionMapper.selectList(
                new LambdaQueryWrapper<PracticeQuestion>().eq(PracticeQuestion::getStatus, 1));
        Map<String, Long> counts = all.stream().collect(Collectors.groupingBy(
                PracticeQuestion::getKnowledgeTag, Collectors.counting()));
        counts.forEach((tag, cnt) -> {
            PracticeStatsVO.ByKnowledgeTag entry = byTag.computeIfAbsent(tag,
                    k -> PracticeStatsVO.ByKnowledgeTag.builder().knowledgeTag(k).build());
            entry.setTotal(cnt);
        });
    }

    private void practiceDeptCounts(Map<String, PracticeStatsVO.ByDepartment> byDept) {
        List<PracticeQuestion> all = questionMapper.selectList(
                new LambdaQueryWrapper<PracticeQuestion>().eq(PracticeQuestion::getStatus, 1));
        Map<String, Long> counts = all.stream().filter(q -> q.getDepartment() != null)
                .collect(Collectors.groupingBy(PracticeQuestion::getDepartment, Collectors.counting()));
        counts.forEach((dept, cnt) -> {
            PracticeStatsVO.ByDepartment entry = byDept.computeIfAbsent(dept,
                    d -> PracticeStatsVO.ByDepartment.builder().department(d).build());
            entry.setTotal(cnt);
        });
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
                .sourceTextbookTitle(q.getSourceTextbookId() == null ? null : tbTitleMap.get(q.getSourceTextbookId()))
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
}