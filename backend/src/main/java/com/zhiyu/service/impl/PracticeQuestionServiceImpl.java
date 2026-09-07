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
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.StudentPracticeRecord;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
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
import java.util.HashMap;
import java.util.HashSet;
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
    private final StudentMistakesMapper mistakesMapper;
    private final com.zhiyu.service.support.MistakeAnalysisTrigger mistakeAnalysisTrigger;
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
                .eq(PracticeQuestion::getAdminAuditStatus, 2)
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
        applyUserStatus(page.getRecords(), list);
        return PageResult.of(page, list);
    }

    @Override
    public PageResult<PracticeQuestionVO> pageByDepartment(Integer pageNum, Integer pageSize,
                                                           String department, Integer difficulty) {
        Page<PracticeQuestion> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<PracticeQuestion> wrapper = new LambdaQueryWrapper<PracticeQuestion>()
                .eq(PracticeQuestion::getStatus, 1)
                .eq(PracticeQuestion::getAdminAuditStatus, 2)
                .eq(StringUtils.hasText(department), PracticeQuestion::getDepartment, department)
                .ge(difficulty != null, PracticeQuestion::getDifficulty, difficulty)
                .orderByAsc(PracticeQuestion::getDifficulty)
                .orderByAsc(PracticeQuestion::getId);
        questionMapper.selectPage(page, wrapper);

        Map<Long, String> tbTitleMap = loadTextbookTitles(page.getRecords());
        List<PracticeQuestionVO> list = page.getRecords().stream()
                .map(q -> toVO(q, tbTitleMap))
                .collect(Collectors.toList());
        applyUserStatus(page.getRecords(), list);
        return PageResult.of(page, list);
    }

    @Override
    public List<String> departments() {
        return questionMapper.selectList(
                        new LambdaQueryWrapper<PracticeQuestion>()
                                .eq(PracticeQuestion::getStatus, 1)
                .eq(PracticeQuestion::getAdminAuditStatus, 2)
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
                .eq(PracticeQuestion::getAdminAuditStatus, 2)
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
        if (q == null || q.getStatus() == 0 || q.getAdminAuditStatus() == null
                || q.getAdminAuditStatus() != 2) {
            throw new BizException(ResultCode.NOT_FOUND, "题目不存在或未通过审核");
        }
        PracticeQuestionVO vo = toVO(q, loadTextbookTitles(Collections.singletonList(q)));
        applyUserStatus(Collections.singletonList(q), Collections.singletonList(vo));
        return vo;
    }

    /**
     * 账户级作答状态：把当前学生对该批题目的「最近一次」作答结果（是否已做 / 所选答案 /
     * 是否答对）回填到 VO。只有已登录的学生才会填充；未登录则保持 null。
     */
    private void applyUserStatus(List<PracticeQuestion> questions, List<PracticeQuestionVO> vos) {
        if (questions == null || questions.isEmpty() || vos == null || vos.isEmpty()) {
            return;
        }
        UserContext.LoginUser user = UserContext.get();
        if (user == null || user.getUserId() == null) {
            return;
        }
        List<Long> qids = questions.stream()
                .map(PracticeQuestion::getId)
                .filter(Objects::nonNull)
                .collect(Collectors.toList());
        if (qids.isEmpty()) {
            return;
        }
        // 最近一次作答记录（按题目分组取 answered_at 最新的一条）
        Map<Long, StudentPracticeRecord> latest = new HashMap<>();
        recordMapper.selectList(new LambdaQueryWrapper<StudentPracticeRecord>()
                        .eq(StudentPracticeRecord::getStudentId, user.getUserId())
                        .in(StudentPracticeRecord::getQuestionId, qids)
                        .orderByDesc(StudentPracticeRecord::getAnsweredAt))
                .forEach(r -> latest.putIfAbsent(r.getQuestionId(), r));
        if (latest.isEmpty()) {
            return;
        }
        for (PracticeQuestionVO vo : vos) {
            StudentPracticeRecord r = latest.get(vo.getId());
            if (r == null) {
                continue;
            }
            vo.setAnswered(true);
            vo.setMyAnswer(r.getSelectedAnswer());
            vo.setCorrect(r.getIsCorrect());
        }
    }

    @Override
    public SubmitResultVO submit(PracticeAnswerDTO dto) {
        Long studentId = UserContext.requireUserId();
        PracticeQuestion q = questionMapper.selectById(dto.getQuestionId());
        if (q == null || q.getStatus() == 0 || q.getAdminAuditStatus() == null
                || q.getAdminAuditStatus() != 2) {
            throw new BizException(ResultCode.NOT_FOUND, "题目不存在或未通过审核");
        }
        // 简答 / 论述等主观题无法机器判分：isCorrect 置 null，交由学生对照参考答案自评
        boolean manual = isManualType(q.getQuestionType());
        Boolean correct = manual ? null : judgeAnswer(q, dto.getSelectedAnswer());

        StudentPracticeRecord record = new StudentPracticeRecord();
        record.setStudentId(studentId);
        record.setQuestionId(q.getId());
        record.setSelectedAnswer(dto.getSelectedAnswer());
        record.setIsCorrect(correct);
        record.setAnsweredAt(LocalDateTime.now());
        recordMapper.insert(record);

        // 训练→错题本闭环：答错收入错题本；已有错题后答对推进连续答对计数并判掌握；
        // 再答错则降级回未复习并累计（连续错>=2 标需加强）。
        syncMistakeForPractice(studentId, q, dto.getSelectedAnswer(), correct);

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

    /** 简答 / 论述等主观题型（需人工对照参考答案自评，不自动判分） */
    private boolean isManualType(String type) {
        return "short_answer".equalsIgnoreCase(type) || "essay".equalsIgnoreCase(type);
    }

    /** 连续答对几次判定「已掌握」（已掌握错题仍保留，仅状态置 2） */
    public static final int MISTAKE_MASTER_THRESHOLD = 2;

    /**
     * 训练→错题本闭环状态机（仅客观/可自动判题题型触发，主观题 correct==null 不参与）。
     *
     * <ul>
     *   <li>无错题记录 & 答错：收入错题本（未复习，连续对=0，累计错=1）</li>
     *   <li>已有记录 & 答对：连续答对 +1；达标阈值 → 已掌握(2)；未达标 → 至少置已复习(1)</li>
     *   <li>已有记录 & 答错：连续答对归零，累计错 +1；累计错≥2 置「需加强」；状态回到未复习(0)
     *       （已掌握后再度答错视为遗忘，降级处理）</li>
     * </ul>
     */
    private void syncMistakeForPractice(Long studentId, PracticeQuestion q, String selected, Boolean correct) {
        if (correct == null) {
            return;
        }
        StudentMistakes existing = mistakesMapper.selectOne(new LambdaQueryWrapper<StudentMistakes>()
                .eq(StudentMistakes::getStudentId, studentId)
                .eq(StudentMistakes::getQuestionId, q.getId())
                .eq(StudentMistakes::getMistakeType, "practice")
                .last("LIMIT 1"));
        if (existing == null) {
            // 首次答错才收入；首次答对不产生错题记录
            if (Boolean.FALSE.equals(correct)) {
                StudentMistakes m = new StudentMistakes();
                m.setStudentId(studentId);
                m.setQuestionId(q.getId());
                m.setMistakeType("practice");
                m.setKnowledgeTag(q.getKnowledgeTag());
                m.setStudentAnswer(selected);
                m.setStandardAnswer(q.getAnswer());
                m.setResolvedStatus(0);
                m.setConsecutiveCorrect(0);
                m.setWrongCount(1);
                m.setFocusFlag(0);
                mistakesMapper.insert(m);
                // 入库后异步预生成 AI 归因，学生打开错题本即可看到分叉定位，无需手动点击
                mistakeAnalysisTrigger.triggerAfterCommit(m.getId(), studentId);
            }
            return;
        }

        int consecutive = existing.getConsecutiveCorrect() == null ? 0 : existing.getConsecutiveCorrect();
        int wrong = existing.getWrongCount() == null ? 0 : existing.getWrongCount();
        int status = existing.getResolvedStatus() == null ? 0 : existing.getResolvedStatus();

        StudentMistakes upd = new StudentMistakes();
        upd.setId(existing.getId());
        if (Boolean.TRUE.equals(correct)) {
            int newConsecutive = consecutive + 1;
            upd.setConsecutiveCorrect(newConsecutive);
            if (status != 2 && newConsecutive >= MISTAKE_MASTER_THRESHOLD) {
                upd.setResolvedStatus(2); // 连续做对满阈值 -> 已掌握
            } else if (status != 2) {
                upd.setResolvedStatus(1); // 未达标 -> 至少视为已复习
            }
            // status 已为 2：保持已掌握，仅刷新连续答对数
            // 答对不清“需加强”标记：是否掌握由连对次数独立判定，focusFlag 单独服务薄弱题提示
        } else {
            upd.setConsecutiveCorrect(0);
            upd.setWrongCount(wrong + 1);
            upd.setResolvedStatus(0);      // 再答错：回到未复习（含已掌握后的遗忘降级）
            upd.setFocusFlag(wrong + 1 >= 2 ? 1 : 0); // 连续答错>=2 需加强
        }
        mistakesMapper.updateById(upd);
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
                new LambdaQueryWrapper<PracticeQuestion>().eq(PracticeQuestion::getStatus, 1)
                .eq(PracticeQuestion::getAdminAuditStatus, 2));

        List<StudentPracticeRecord> records = recordMapper.selectList(
                new LambdaQueryWrapper<StudentPracticeRecord>()
                        .eq(StudentPracticeRecord::getStudentId, studentId));

        // 按「不同题目」去重：同一题反复作答只算一次已做，答对按历次任一次答对计，
        // 避免重复刷同一题被反复计入统计（练习过的题重做不应再增加已做/答对数）。
        Set<Long> answeredIds = new HashSet<>();
        Set<Long> correctIds = new HashSet<>();
        for (StudentPracticeRecord r : records) {
            if (r.getQuestionId() == null) {
                continue;
            }
            answeredIds.add(r.getQuestionId());
            if (Boolean.TRUE.equals(r.getIsCorrect())) {
                correctIds.add(r.getQuestionId());
            }
        }
        long totalAnswered = answeredIds.size();
        long correctCount = correctIds.size();

        // 按知识点聚合
        Map<String, PracticeStatsVO.ByKnowledgeTag> byTag = new LinkedHashMap<>();
        practiceTagCounts(byTag); // 题库各知识点总量
        // 按科室（模块）聚合
        Map<String, PracticeStatsVO.ByDepartment> byDept = new LinkedHashMap<>();
        practiceDeptCounts(byDept); // 题库各科室总量

        Map<Long, PracticeQuestion> qCache = new HashMap<>();
        for (Long qid : answeredIds) {
            PracticeQuestion q = qCache.computeIfAbsent(qid, questionMapper::selectById);
            if (q == null) {
                continue;
            }
            boolean correct = correctIds.contains(qid);
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
                new LambdaQueryWrapper<PracticeQuestion>().eq(PracticeQuestion::getStatus, 1)
                .eq(PracticeQuestion::getAdminAuditStatus, 2));
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
                new LambdaQueryWrapper<PracticeQuestion>().eq(PracticeQuestion::getStatus, 1)
                .eq(PracticeQuestion::getAdminAuditStatus, 2));
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
                .questionNo(q.getQuestionNo())
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