package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
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

    // ==================== 低频变动数据的进程内缓存 ====================
    //
    // 科室 / 知识点列表几乎不随请求变化（仅题库导入、教师录题时变），但每次进题库页
    // 都触发一次全表 GROUP BY（5.6 万行实测 126/142ms）。这里用进程内 TTL 缓存兜底；
    // 题库写入路径调用 evictQuestionMetaCache() 立即失效，避免最长 5 分钟陈旧窗口。
    private static final long META_CACHE_TTL_MS = 5 * 60 * 1000L;
    private static volatile List<String> departmentsCache;
    private static volatile long departmentsCacheAt;
    private static volatile List<String> knowledgeTagsCache;
    private static volatile long knowledgeTagsCacheAt;

    /** 题库结构（科室 / 知识点）变更后调用，立即刷新列表缓存 */
    public static void evictQuestionMetaCache() {
        departmentsCache = null;
        knowledgeTagsCache = null;
    }

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
        List<String> cached = departmentsCache;
        if (cached != null && System.currentTimeMillis() - departmentsCacheAt < META_CACHE_TTL_MS) {
            return cached;
        }
        List<String> list = questionMapper.selectList(
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
        departmentsCache = list;
        departmentsCacheAt = System.currentTimeMillis();
        return list;
    }

    @Override
    public List<String> knowledgeTags() {
        List<String> cached = knowledgeTagsCache;
        if (cached != null && System.currentTimeMillis() - knowledgeTagsCacheAt < META_CACHE_TTL_MS) {
            return cached;
        }
        List<String> list = questionMapper.selectList(
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
        knowledgeTagsCache = list;
        knowledgeTagsCacheAt = System.currentTimeMillis();
        return list;
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

        // 我的作答：一条聚合 SQL 拿「每题是否曾答对」，替代旧实现的
        // 全量作答记录 selectList + 逐题 selectById（N+1，题目越多越慢）。
        Map<Long, Boolean> everCorrectByQuestion = new HashMap<>();
        recordMapper.selectMaps(new QueryWrapper<StudentPracticeRecord>()
                        .select("question_id",
                                "MAX(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) AS ever_correct")
                        .eq("student_id", studentId)
                        .groupBy("question_id"))
                .forEach(row -> {
                    Object qid = row.get("question_id");
                    if (qid instanceof Number n) {
                        Object flag = row.get("ever_correct");
                        boolean everCorrect = flag instanceof Number b && b.longValue() == 1;
                        everCorrectByQuestion.put(n.longValue(), everCorrect);
                    }
                });

        // 按「不同题目」去重：同一题反复作答只算一次已做，答对按历次任一次答对计，
        // 避免重复刷同一题被反复计入统计（练习过的题重做不应再增加已做/答对数）。
        long totalAnswered = everCorrectByQuestion.size();
        long correctCount = everCorrectByQuestion.values().stream()
                .filter(Boolean::booleanValue).count();

        // 按知识点聚合
        Map<String, PracticeStatsVO.ByKnowledgeTag> byTag = new LinkedHashMap<>();
        practiceTagCounts(byTag); // 题库各知识点总量（聚合 SQL，不捞实体）
        // 按科室（模块）聚合
        Map<String, PracticeStatsVO.ByDepartment> byDept = new LinkedHashMap<>();
        practiceDeptCounts(byDept); // 题库各科室总量（聚合 SQL，不捞实体）

        // 我的题目维度信息：批量一次查回，只取聚合需要的两列，
        // 不捞题干 / 选项 / 解析等大字段（旧实现逐题 selectById 是 N+1）。
        if (!everCorrectByQuestion.isEmpty()) {
            List<PracticeQuestion> mine = questionMapper.selectList(
                    new LambdaQueryWrapper<PracticeQuestion>()
                            .in(PracticeQuestion::getId, everCorrectByQuestion.keySet())
                            .select(PracticeQuestion::getId, PracticeQuestion::getKnowledgeTag,
                                    PracticeQuestion::getDepartment));
            for (PracticeQuestion q : mine) {
                boolean correct = Boolean.TRUE.equals(everCorrectByQuestion.get(q.getId()));
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

    /** 题库各知识点总量：聚合 SQL 在库里计数，替代把全表 5.6 万题捞进内存再分组 */
    private void practiceTagCounts(Map<String, PracticeStatsVO.ByKnowledgeTag> byTag) {
        questionMapper.selectMaps(new QueryWrapper<PracticeQuestion>()
                        .select("knowledge_tag", "COUNT(*) AS total")
                        .eq("status", 1)
                        .eq("admin_audit_status", 2)
                        .groupBy("knowledge_tag"))
                .forEach(row -> {
                    Object tag = row.get("knowledge_tag");
                    Object total = row.get("total");
                    if (tag instanceof String s && StringUtils.hasText(s) && total instanceof Number n) {
                        byTag.computeIfAbsent(s, k -> PracticeStatsVO.ByKnowledgeTag
                                        .builder().knowledgeTag(k).build())
                                .setTotal(n.longValue());
                    }
                });
    }

    /** 题库各科室总量：聚合 SQL 在库里计数，替代把全表 5.6 万题捞进内存再分组 */
    private void practiceDeptCounts(Map<String, PracticeStatsVO.ByDepartment> byDept) {
        questionMapper.selectMaps(new QueryWrapper<PracticeQuestion>()
                        .select("department", "COUNT(*) AS total")
                        .eq("status", 1)
                        .eq("admin_audit_status", 2)
                        .groupBy("department"))
                .forEach(row -> {
                    Object dept = row.get("department");
                    Object total = row.get("total");
                    if (dept instanceof String d && StringUtils.hasText(d) && total instanceof Number n) {
                        byDept.computeIfAbsent(d, k -> PracticeStatsVO.ByDepartment
                                        .builder().department(k).build())
                                .setTotal(n.longValue());
                    }
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