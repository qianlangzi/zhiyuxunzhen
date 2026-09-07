package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.toolkit.Db;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentItem;
import com.zhiyu.entity.AssignmentItemProgress;
import com.zhiyu.entity.AssignmentTargetClass;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.AssignmentTargetClassMapper;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.FormatCheckService;
import com.zhiyu.service.StudentAssignmentService;
import com.zhiyu.service.dto.PracticeSubmitDTO;
import com.zhiyu.service.dto.SubmitRecordDTO;
import com.zhiyu.vo.FormatCheckResultVO;
import com.zhiyu.vo.PracticeSubmitResultVO;
import com.zhiyu.vo.StudentAssignmentDetailVO;
import com.zhiyu.vo.StudentAssignmentVO;
import com.zhiyu.vo.StudentItemDetailVO;
import com.zhiyu.vo.StudentItemVO;
import com.zhiyu.vo.StudentQuestionVO;
import com.zhiyu.vo.SubmitRecordResultVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 学生作业服务实现（组合任务包）
 * 作业 = 任务包(CASE病例问诊 / PRACTICE基础练习 / READING阅读任务)，学生逐任务项完成。
 * 兼容存量单病例作业。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentAssignmentServiceImpl implements StudentAssignmentService {

    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentMapper assignmentMapper;
    private final AssignmentTargetClassMapper targetClassMapper;
    private final TeachingClassMapper teachingClassMapper;
    private final AssignmentItemMapper itemMapper;
    private final AssignmentItemProgressMapper progressMapper;
    private final SpCaseConfigMapper caseMapper;
    private final PracticeQuestionMapper questionMapper;
    private final TextbookMapper textbookMapper;
    private final FormatCheckService formatCheckService;
    private final ObjectMapper objectMapper;
    private final AiPlatformClient aiPlatformClient;

    @Override
    public PageResult<StudentAssignmentVO> myAssignments(Integer pageNum, Integer pageSize) {
        Long studentId = UserContext.requireUserId();
        Page<AssignmentInstance> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<AssignmentInstance> wrapper = new LambdaQueryWrapper<AssignmentInstance>()
                .eq(AssignmentInstance::getStudentId, studentId)
                .orderByDesc(AssignmentInstance::getCreatedAt);
        instanceMapper.selectPage(page, wrapper);
        List<StudentAssignmentVO> list = buildVOs(page.getRecords());
        return PageResult.of(page, list);
    }

    @Override
    public PageResult<StudentAssignmentVO> todoAssignments(Integer pageNum, Integer pageSize) {
        Long studentId = UserContext.requireUserId();
        Page<AssignmentInstance> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<AssignmentInstance> wrapper = new LambdaQueryWrapper<AssignmentInstance>()
                .eq(AssignmentInstance::getStudentId, studentId)
                .in(AssignmentInstance::getStatus, 0, 1, 2)
                .orderByDesc(AssignmentInstance::getCreatedAt);
        instanceMapper.selectPage(page, wrapper);
        return PageResult.of(page, buildVOs(page.getRecords()));
    }

    /** 批量补全作业标题、病例标题、截止时间、任务项，组装列表 VO */
    private List<StudentAssignmentVO> buildVOs(List<AssignmentInstance> records) {
        List<Long> assignmentIds = records.stream()
                .map(AssignmentInstance::getAssignmentId).filter(Objects::nonNull).distinct().toList();
        List<Long> caseIds = records.stream()
                .map(AssignmentInstance::getCaseId).filter(Objects::nonNull).distinct().toList();
        Map<Long, Assignment> aMap = batchAssignmentMap(assignmentIds);
        Map<Long, SpCaseConfig> cMap = batchCaseMap(caseIds);
        // 组合包任务项进度
        Map<Long, List<StudentItemVO>> itemMap = loadItemSummary(assignmentIds, records);
        // 作业→班级名（支持学生端按课程分组汇总待办）
        Map<Long, String> classNameByAssignment = loadClassNameMap(assignmentIds);

        return records.stream().map(inst -> {
            Assignment a = aMap.get(inst.getAssignmentId());
            SpCaseConfig c = cMap.get(inst.getCaseId());
            return StudentAssignmentVO.builder()
                    .instanceId(inst.getId())
                    .assignmentId(inst.getAssignmentId())
                    .assignmentTitle(a == null ? null : a.getTitle())
                    .caseId(inst.getCaseId())
                    .caseTitle(c == null ? null : c.getTitle())
                    .className(classNameByAssignment.get(inst.getAssignmentId()))
                    .deadline(a == null ? null : a.getDeadline())
                    .status(inst.getStatus())
                    .score(inst.getScore())
                    .items(itemMap.get(inst.getId()))
                    .build();
        }).collect(Collectors.toList());
    }

    @Override
    public StudentAssignmentDetailVO detail(Long instanceId) {
        Long studentId = UserContext.requireUserId();
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
        }
        if (!studentId.equals(inst.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN);
        }
        Assignment a = assignmentMapper.selectById(inst.getAssignmentId());
        SpCaseConfig c = inst.getCaseId() == null ? null : caseMapper.selectById(inst.getCaseId());
        int status = inst.getStatus() == null ? 0 : inst.getStatus();

        StudentAssignmentDetailVO.StudentAssignmentDetailVOBuilder builder = StudentAssignmentDetailVO.builder()
                .instanceId(inst.getId())
                .assignmentId(inst.getAssignmentId())
                .assignmentTitle(a == null ? null : a.getTitle())
                .assignmentDescription(a == null ? null : a.getDescription())
                .caseId(inst.getCaseId())
                .caseTitle(c == null ? null : c.getTitle())
                .department(c == null ? null : c.getDepartment())
                .deadline(a == null ? null : a.getDeadline())
                .allowLateSubmit(a == null ? null : a.getAllowLateSubmit())
                .status(status)
                .score(inst.getScore())
                .submitTime(inst.getSubmitTime())
                .medicalRecordText(inst.getMedicalRecordText())
                .formatCheckResult(inst.getFormatCheckResult())
                .submitted(status == 2 || status == 3 || status == 4 || status == 5);

        // 组合包:任务项详情
        List<AssignmentItem> items = itemMapper.selectList(
                new LambdaQueryWrapper<AssignmentItem>()
                        .eq(AssignmentItem::getAssignmentId, inst.getAssignmentId())
                        .orderByAsc(AssignmentItem::getSortOrder));
        if (!items.isEmpty()) {
            List<AssignmentItemProgress> progresses = progressMapper.selectList(
                    new LambdaQueryWrapper<AssignmentItemProgress>()
                            .eq(AssignmentItemProgress::getInstanceId, instanceId));
            Map<Long, AssignmentItemProgress> progressByItem = progresses.stream()
                    .collect(Collectors.toMap(AssignmentItemProgress::getItemId, p -> p));
            List<StudentItemDetailVO> itemVOs = new ArrayList<>();
            for (AssignmentItem item : items) {
                itemVOs.add(buildItemDetail(item, progressByItem.get(item.getId())));
            }
            builder.items(itemVOs);
        }
        return builder.build();
    }

    /** 组装单个任务项详情 */
    private StudentItemDetailVO buildItemDetail(AssignmentItem item, AssignmentItemProgress p) {
        int pStatus = p == null ? 0 : (p.getStatus() == null ? 0 : p.getStatus());
        StudentItemDetailVO.StudentItemDetailVOBuilder b = StudentItemDetailVO.builder()
                .itemId(item.getId())
                .progressId(p == null ? null : p.getId())
                .itemType(item.getItemType())
                .title(item.getTitle())
                .status(pStatus)
                .score(p == null ? null : p.getScore())
                .submitTime(p == null ? null : p.getSubmitTime())
                .completedAt(p == null ? null : p.getCompletedAt());
        switch (item.getItemType()) {
            case "CASE" -> {
                SpCaseConfig c = item.getCaseId() == null ? null : caseMapper.selectById(item.getCaseId());
                b.caseId(item.getCaseId());
                b.caseTitle(c == null ? null : c.getTitle());
                b.department(c == null ? null : c.getDepartment());
                b.sessionId(p == null ? null : p.getSessionId());
                b.medicalRecordText(p == null ? null : p.getMedicalRecordText());
                b.formatCheckResult(p == null ? null : p.getFormatCheckResult());
            }
            case "PRACTICE" -> b.questions(loadQuestions(item));
            case "READING" -> {
                Textbook t = item.getTextbookId() == null ? null : textbookMapper.selectById(item.getTextbookId());
                b.textbookId(item.getTextbookId());
                b.textbookTitle(t == null ? null : t.getTitle());
                b.textbookFileUrl(t == null ? null : t.getFileUrl());
                b.readingScope(item.getReadingScope());
            }
            default -> { }
        }
        return b.build();
    }

    /** 练习任务项题目列表（不含答案） */
    private List<StudentQuestionVO> loadQuestions(AssignmentItem item) {
        List<Long> ids = parseQuestionIds(item.getQuestionIds());
        if (ids.isEmpty()) return List.of();
        List<PracticeQuestion> questions = questionMapper.selectBatchIds(ids);
        Map<Long, PracticeQuestion> qMap = questions.stream()
                .collect(Collectors.toMap(PracticeQuestion::getId, q -> q));
        // 按作业配置的题目顺序返回
        return ids.stream().map(qMap::get).filter(Objects::nonNull)
                .map(q -> StudentQuestionVO.builder()
                        .id(q.getId()).questionType(q.getQuestionType()).title(q.getTitle())
                        .optionsJson(q.getOptionsJson()).difficulty(q.getDifficulty())
                        .knowledgeTag(q.getKnowledgeTag()).build())
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public SubmitRecordResultVO submitRecord(Long instanceId, Long itemProgressId, SubmitRecordDTO req) {
        Long studentId = UserContext.requireUserId();
        AssignmentInstance inst = checkInstance(instanceId, studentId);
        if (itemProgressId != null) {
            // ---------- 组合包:提交病例任务项大病历 ----------
            AssignmentItemProgress p = checkProgress(itemProgressId, instanceId, studentId);
            AssignmentItem item = itemMapper.selectById(p.getItemId());
            if (item == null || !"CASE".equals(item.getItemType())) {
                throw new BizException(ResultCode.BAD_REQUEST, "任务项不是病例任务");
            }
            int pStatus = p.getStatus() == null ? 0 : p.getStatus();
            if (pStatus == 3 || pStatus == 4 || pStatus == 5) {
                throw new BizException(ResultCode.DUPLICATE_SUBMIT);
            }
            checkDeadline(inst.getAssignmentId());

            String rule = item.getFormatRuleJson();
            FormatCheckResultVO checkResult = formatCheckService.check(req.getMedicalRecordText(), rule);
            p.setMedicalRecordText(req.getMedicalRecordText());
            p.setSubmitTime(LocalDateTime.now());
            p.setFormatCheckResult(toJson(checkResult));
            p.setStatus(Boolean.TRUE.equals(checkResult.getPassed()) ? 3 : 2);
            progressMapper.updateById(p);
            refreshInstanceStatus(inst);

            if (Boolean.TRUE.equals(checkResult.getPassed())) {
                Long progressId = p.getId();
                String medicalText = req.getMedicalRecordText();
                afterCommit(() -> triggerAiReview(progressId, medicalText));
            }
            return SubmitRecordResultVO.builder()
                    .instanceId(instanceId)
                    .status(p.getStatus())
                    .passed(checkResult.getPassed())
                    .formatCheckResult(checkResult)
                    .build();
        }

        // ---------- 存量:提交作业实例大病历 ----------
        int status = inst.getStatus() == null ? 0 : inst.getStatus();
        if (status == 3 || status == 4 || status == 5) {
            throw new BizException(ResultCode.DUPLICATE_SUBMIT);
        }
        Assignment a = assignmentMapper.selectById(inst.getAssignmentId());
        if (a == null) {
            throw new BizException(ResultCode.ASSIGNMENT_NOT_FOUND);
        }
        checkDeadline(inst.getAssignmentId());
        FormatCheckResultVO checkResult = formatCheckService.check(req.getMedicalRecordText(), a.getFormatRuleJson());
        inst.setMedicalRecordText(req.getMedicalRecordText());
        inst.setSubmitTime(LocalDateTime.now());
        inst.setFormatCheckResult(toJson(checkResult));
        inst.setStatus(Boolean.TRUE.equals(checkResult.getPassed()) ? 3 : 2);
        instanceMapper.updateById(inst);
        if (Boolean.TRUE.equals(checkResult.getPassed())) {
            Long instIdRef = inst.getId();
            String medicalText = req.getMedicalRecordText();
            afterCommit(() -> triggerAiReview(instIdRef, medicalText));
        }
        return SubmitRecordResultVO.builder()
                .instanceId(instanceId)
                .status(inst.getStatus())
                .passed(checkResult.getPassed())
                .formatCheckResult(checkResult)
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public PracticeSubmitResultVO submitPractice(Long instanceId, Long itemProgressId, PracticeSubmitDTO req) {
        Long studentId = UserContext.requireUserId();
        if (itemProgressId == null) {
            throw new BizException(ResultCode.BAD_REQUEST, "缺少任务项进度ID");
        }
        AssignmentInstance inst = checkInstance(instanceId, studentId);
        AssignmentItemProgress p = checkProgress(itemProgressId, instanceId, studentId);
        AssignmentItem item = itemMapper.selectById(p.getItemId());
        if (item == null || !"PRACTICE".equals(item.getItemType())) {
            throw new BizException(ResultCode.BAD_REQUEST, "任务项不是练习任务");
        }
        int pStatus = p.getStatus() == null ? 0 : p.getStatus();
        if (pStatus == 5) {
            throw new BizException(ResultCode.DUPLICATE_SUBMIT);
        }
        checkDeadline(inst.getAssignmentId());

        List<Long> ids = parseQuestionIds(item.getQuestionIds());
        Map<Long, PracticeQuestion> qMap = ids.isEmpty() ? Map.of()
                : questionMapper.selectBatchIds(ids).stream()
                        .collect(Collectors.toMap(PracticeQuestion::getId, q -> q));

        // 判分：客观题自动判分；主观题（简答/论述）收集作答交教师复核，不做自动判分
        int total = 0, correct = 0;
        boolean hasSubjective = false;
        Map<Long, Boolean> result = new LinkedHashMap<>();
        Map<String, Object> answersJson = new LinkedHashMap<>();
        Map<Long, String> answers = req.getAnswers() == null ? Map.of() : req.getAnswers();
        for (Long qid : ids) {
            PracticeQuestion q = qMap.get(qid);
            if (q == null) continue;
            String selected = answers.get(qid);
            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("answer", selected == null ? "" : selected);
            if (isSubjective(q.getQuestionType())) {
                // 主观题：不参与自动判分，由教师端 AI 批改/复核
                hasSubjective = true;
                entry.put("correct", null);
                answersJson.put(String.valueOf(qid), entry);
                continue;
            }
            total++;
            boolean isCorrect = judgeAnswer(q, selected);
            if (isCorrect) correct++;
            result.put(qid, isCorrect);
            entry.put("correct", isCorrect);
            answersJson.put(String.valueOf(qid), entry);
        }
        BigDecimal score = total == 0 ? BigDecimal.ZERO
                : BigDecimal.valueOf(Math.round(correct * 100.0 / total * 10) / 10.0);
        // 含主观题的任务项进入"待教师复核(3)"，客观题自动判分已完成
        int targetStatus = hasSubjective ? 3 : 5;

        p.setAnswersJson(toJson(answersJson));
        p.setScore(score);
        p.setSubmitTime(LocalDateTime.now());
        p.setCompletedAt(LocalDateTime.now());
        p.setStatus(targetStatus);
        progressMapper.updateById(p);
        refreshInstanceStatus(inst);

        return PracticeSubmitResultVO.builder()
                .itemProgressId(p.getId())
                .status(targetStatus)
                .score(score)
                .total(total)
                .correct(correct)
                .result(result)
                .build();
    }

    /** 是否为需人工复核的主观题（简答/论述） */
    private boolean isSubjective(String type) {
        return type != null
                && ("essay".equalsIgnoreCase(type)
                    || "short_answer".equalsIgnoreCase(type)
                    || "subjective".equalsIgnoreCase(type));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public PracticeSubmitResultVO completeReading(Long instanceId, Long itemProgressId) {
        Long studentId = UserContext.requireUserId();
        if (itemProgressId == null) {
            throw new BizException(ResultCode.BAD_REQUEST, "缺少任务项进度ID");
        }
        AssignmentInstance inst = checkInstance(instanceId, studentId);
        AssignmentItemProgress p = checkProgress(itemProgressId, instanceId, studentId);
        AssignmentItem item = itemMapper.selectById(p.getItemId());
        if (item == null || !"READING".equals(item.getItemType())) {
            throw new BizException(ResultCode.BAD_REQUEST, "任务项不是阅读任务");
        }
        int pStatus = p.getStatus() == null ? 0 : p.getStatus();
        if (pStatus == 5) {
            return PracticeSubmitResultVO.builder().itemProgressId(p.getId()).status(5).build();
        }
        p.setCompletedAt(LocalDateTime.now());
        p.setStatus(5);
        progressMapper.updateById(p);
        refreshInstanceStatus(inst);
        return PracticeSubmitResultVO.builder().itemProgressId(p.getId()).status(5).build();
    }

    // ========= 辅助方法 =========

    private AssignmentInstance checkInstance(Long instanceId, Long studentId) {
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
        }
        if (!studentId.equals(inst.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN);
        }
        return inst;
    }

    private AssignmentItemProgress checkProgress(Long itemProgressId, Long instanceId, Long studentId) {
        AssignmentItemProgress p = progressMapper.selectById(itemProgressId);
        if (p == null || !instanceId.equals(p.getInstanceId()) || !studentId.equals(p.getStudentId())) {
            throw new BizException(ResultCode.BAD_REQUEST, "任务项进度不存在或不属于当前学生");
        }
        return p;
    }

    private void checkDeadline(Long assignmentId) {
        Assignment a = assignmentMapper.selectById(assignmentId);
        if (a == null) {
            throw new BizException(ResultCode.ASSIGNMENT_NOT_FOUND);
        }
        LocalDateTime now = LocalDateTime.now();
        boolean allowLate = a.getAllowLateSubmit() != null && a.getAllowLateSubmit();
        if (a.getDeadline() != null && now.isAfter(a.getDeadline()) && !allowLate) {
            throw new BizException(ResultCode.ASSIGNMENT_DEADLINE_PASSED);
        }
    }

    /** 按题型判题（兼容存量下标格式与字母/文本格式） */
    private boolean judgeAnswer(PracticeQuestion q, String selected) {
        if (selected == null) {
            return false;
        }
        String type = q.getQuestionType();
        String correct = q.getAnswer() == null ? "" : q.getAnswer().trim();
        List<String> options = parseQuestionOptions(q.getOptionsJson());

        if ("judgment".equalsIgnoreCase(type)) {
            return normalizeJudgment(selected, options).equals(normalizeJudgment(correct, options));
        }
        if ("multiple_choice".equalsIgnoreCase(type)) {
            return normalizeChoiceSet(selected, options).equals(normalizeChoiceSet(correct, options));
        }
        if ("fill_blank".equalsIgnoreCase(type)) {
            return normalizeBlank(selected).equals(normalizeBlank(correct));
        }
        // single_choice：统一转选项下标比较
        return normalizeSingle(selected, options).equals(normalizeSingle(correct, options));
    }

    private String normalizeSingle(String v, List<String> options) {
        v = v.trim();
        if (v.isEmpty()) return v;
        // 纯数字 → 选项下标
        if (v.matches("\\d+")) {
            int idx = Integer.parseInt(v);
            return idx < options.size() ? String.valueOf(idx) : v;
        }
        // 大写字母 → 选项下标
        if (v.length() == 1 && v.charAt(0) >= 'A' && v.charAt(0) <= 'Z') {
            int idx = v.charAt(0) - 'A';
            return idx < options.size() ? String.valueOf(idx) : v;
        }
        // 选项文本 → 选项下标
        int idx = options.indexOf(v);
        if (idx >= 0) return String.valueOf(idx);
        return v;
    }

    private Set<String> normalizeChoiceSet(String v, List<String> options) {
        Set<String> set = new LinkedHashSet<>();
        for (String part : v.split("[,，]")) {
            part = part.trim();
            if (part.isEmpty()) continue;
            set.add(normalizeSingle(part, options));
        }
        return set;
    }

    private String normalizeJudgment(String v, List<String> options) {
        v = v.trim().toLowerCase();
        // 纯数字 → 选项下标 → 选项文本
        if (v.matches("\\d+")) {
            int idx = Integer.parseInt(v);
            if (idx < options.size()) {
                v = options.get(idx).trim().toLowerCase();
            }
        }
        // 常见判断词规范化（含选项文本"正确/错误/对/错"）
        return switch (v) {
            case "0" -> "f";
            case "1" -> "t";
            case "true", "t", "y", "yes" -> "t";
            case "false", "f", "n", "no" -> "f";
            case "对", "正确", "√", "v" -> "t";
            case "错", "错误", "×", "x" -> "f";
            default -> v;
        };
    }

    private String normalizeBlank(String s) {
        return s.trim().replaceAll("\\s+", "").toLowerCase();
    }

    private List<String> parseQuestionOptions(String json) {
        if (json == null || json.isBlank()) return List.of();
        try {
            return objectMapper.readValue(json,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, String.class));
        } catch (Exception e) {
            log.warn("解析题目选项失败: {}", e.getMessage());
            return List.of();
        }
    }

    /** 聚合刷新作业实例状态:全部任务项完成=5,有进行中=1,全未开始=0 */
    private void refreshInstanceStatus(AssignmentInstance inst) {
        List<AssignmentItemProgress> ps = progressMapper.selectList(
                new LambdaQueryWrapper<AssignmentItemProgress>()
                        .eq(AssignmentItemProgress::getInstanceId, inst.getId()));
        if (ps.isEmpty()) return;
        boolean allDone = ps.stream().allMatch(p -> p.getStatus() != null && p.getStatus() == 5);
        boolean anyActive = ps.stream().anyMatch(p -> p.getStatus() != null && p.getStatus() > 0);
        inst.setStatus(allDone ? 5 : (anyActive ? 1 : 0));
        List<BigDecimal> scores = ps.stream().map(p -> p.getScore()).filter(Objects::nonNull).toList();
        if (!scores.isEmpty()) {
            double avg = scores.stream().mapToDouble(BigDecimal::doubleValue).average().orElse(0);
            inst.setScore(BigDecimal.valueOf(Math.round(avg * 10) / 10.0));
        }
        instanceMapper.updateById(inst);
    }

    /** 任务项摘要(列表页):按学生实例分组 */
    private Map<Long, List<StudentItemVO>> loadItemSummary(List<Long> assignmentIds, List<AssignmentInstance> records) {
        Map<Long, List<StudentItemVO>> map = new HashMap<>();
        if (assignmentIds.isEmpty()) return map;
        List<AssignmentItem> items = itemMapper.selectList(
                new LambdaQueryWrapper<AssignmentItem>()
                        .in(AssignmentItem::getAssignmentId, assignmentIds)
                        .orderByAsc(AssignmentItem::getSortOrder));
        if (items.isEmpty()) return map;
        Map<Long, List<AssignmentItem>> itemByAssignment = items.stream()
                .collect(Collectors.groupingBy(AssignmentItem::getAssignmentId));
        List<Long> instIds = records.stream().map(AssignmentInstance::getId).toList();
        Map<Long, List<AssignmentItemProgress>> progByInst = instIds.isEmpty() ? Map.of()
                : progressMapper.selectList(new LambdaQueryWrapper<AssignmentItemProgress>()
                                .in(AssignmentItemProgress::getInstanceId, instIds)).stream()
                        .collect(Collectors.groupingBy(AssignmentItemProgress::getInstanceId));
        Map<Long, AssignmentItemProgress> progByItem = new HashMap<>();
        for (List<AssignmentItemProgress> ps : progByInst.values()) {
            for (AssignmentItemProgress p : ps) {
                progByItem.put(p.getItemId(), p);
            }
        }
        for (AssignmentInstance inst : records) {
            List<AssignmentItem> myItems = itemByAssignment.getOrDefault(inst.getAssignmentId(), List.of());
            if (myItems.isEmpty()) continue;
            List<StudentItemVO> vos = myItems.stream().map(item -> {
                AssignmentItemProgress p = progByItem.get(item.getId());
                return StudentItemVO.builder()
                        .itemId(item.getId())
                        .itemType(item.getItemType())
                        .title(item.getTitle())
                        .status(p == null ? 0 : (p.getStatus() == null ? 0 : p.getStatus()))
                        .score(p == null ? null : p.getScore())
                        .build();
            }).collect(Collectors.toList());
            map.put(inst.getId(), vos);
        }
        return map;
    }

    private List<Long> parseQuestionIds(String json) {
        if (json == null || json.isBlank()) return List.of();
        try {
            return objectMapper.readValue(json,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, Long.class));
        } catch (Exception e) {
            log.warn("解析 questionIds 失败: {}", e.getMessage());
            return List.of();
        }
    }

    private Map<Long, Assignment> batchAssignmentMap(List<Long> ids) {
        Map<Long, Assignment> map = new HashMap<>();
        if (ids.isEmpty()) return map;
        for (Assignment a : assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>().in(Assignment::getId, ids))) {
            map.put(a.getId(), a);
        }
        return map;
    }

    /** 作业→班级名（首个目标班级；支持学生端按课程分组待办） */
    private Map<Long, String> loadClassNameMap(List<Long> assignmentIds) {
        Map<Long, String> map = new HashMap<>();
        if (assignmentIds.isEmpty()) return map;
        List<AssignmentTargetClass> targets = targetClassMapper.selectList(
                new LambdaQueryWrapper<AssignmentTargetClass>()
                        .in(AssignmentTargetClass::getAssignmentId, assignmentIds));
        if (targets.isEmpty()) return map;
        Map<Long, Long> firstClassByAssignment = new HashMap<>();
        targets.forEach(t -> firstClassByAssignment.putIfAbsent(t.getAssignmentId(), t.getClassId()));
        List<Long> classIds = targets.stream().map(AssignmentTargetClass::getClassId)
                .filter(Objects::nonNull).distinct().toList();
        if (!classIds.isEmpty()) {
            Map<Long, String> nameById = new HashMap<>();
            for (TeachingClass c : teachingClassMapper.selectBatchIds(classIds)) {
                if (c != null && c.getId() != null) nameById.put(c.getId(), c.getName());
            }
            firstClassByAssignment.forEach((aid, cid) -> map.put(aid, nameById.get(cid)));
        }
        return map;
    }

    private Map<Long, SpCaseConfig> batchCaseMap(List<Long> ids) {
        Map<Long, SpCaseConfig> map = new HashMap<>();
        if (ids.isEmpty()) return map;
        for (SpCaseConfig c : caseMapper.selectList(
                new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, ids))) {
            map.put(c.getId(), c);
        }
        return map;
    }

    /**
     * 异步触发 AI 批阅（PRD 5.3 / 9.3）。
     * 组合包传任务项进度ID，存量传作业实例ID（AI 中台按不透明 ID 回传）。
     */
    @Async("aiTaskExecutor")
    public void triggerAiReview(Long reviewId, String medicalRecordText) {
        try {
            log.info("触发AI批阅: reviewId={}", reviewId);
            aiPlatformClient.reviewMedicalRecord(reviewId, medicalRecordText);
        } catch (Exception e) {
            log.error("AI批阅触发失败: reviewId={} error={}", reviewId, e.getMessage(), e);
        }
    }

    private void afterCommit(Runnable action) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    action.run();
                }
            });
        } else {
            action.run();
        }
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            log.warn("JSON序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
