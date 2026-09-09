package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.toolkit.Db;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentItem;
import com.zhiyu.entity.AssignmentItemProgress;
import com.zhiyu.entity.AssignmentTargetClass;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentClassMembership;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.TeacherClassAuthorization;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.entity.Textbook;
import com.zhiyu.entity.LessonMaterial;
import com.zhiyu.entity.LessonPlan;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.AssignmentTargetClassMapper;
import com.zhiyu.mapper.LessonMaterialMapper;
import com.zhiyu.mapper.LessonPlanMapper;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentClassMembershipMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TeacherClassAuthorizationMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.TeacherAssignmentService;
import com.zhiyu.service.dto.AssignmentCreateDTO;
import com.zhiyu.service.dto.AssignmentSettingsDTO;
import com.zhiyu.vo.AssignmentItemStatVO;
import com.zhiyu.vo.AssignmentItemVO;
import com.zhiyu.vo.AssignmentProgressVO;
import com.zhiyu.vo.StudentProgressVO;
import com.zhiyu.vo.TeacherAssignmentListVO;
import com.zhiyu.vo.TeachingClassVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 教师作业服务实现（组合任务包）
 * 作业 = 任务包，支持 病例问诊(CASE) / 基础练习(PRACTICE) / 阅读任务(READING) 多个任务项。
 * 发放直接生成学生实例 + 任务项进度，不涉及管理员审核。
 * 兼容存量单病例作业：assignment 无任务项时走旧逻辑。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherAssignmentServiceImpl implements TeacherAssignmentService {

    private final AssignmentMapper assignmentMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentItemMapper itemMapper;
    private final AssignmentItemProgressMapper progressMapper;
    private final SpCaseConfigMapper caseMapper;
    private final SysUserMapper userMapper;
    private final TeachingClassMapper classMapper;
    private final TeacherClassAuthorizationMapper authorizationMapper;
    private final AssignmentTargetClassMapper targetClassMapper;
    private final PracticeQuestionMapper questionMapper;
    private final TextbookMapper textbookMapper;
    private final StudentClassMembershipMapper membershipMapper;
    private final LessonMaterialMapper lessonMaterialMapper;
    private final LessonPlanMapper lessonPlanMapper;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long create(AssignmentCreateDTO req) {
        Long teacherId = UserContext.requireUserId();

        // 1. 校验班级授权（直接发放，不涉及管理员审核）
        List<Long> authorizedClassIds = authorizationMapper.selectList(
                        new LambdaQueryWrapper<TeacherClassAuthorization>()
                                .eq(TeacherClassAuthorization::getTeacherId, teacherId))
                .stream().map(TeacherClassAuthorization::getClassId).toList();
        if (!authorizedClassIds.containsAll(req.getClassIds())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能向已授权班级发放作业");
        }

        // 2. 校验任务项内容归属
        for (AssignmentCreateDTO.Item item : req.getItems()) {
            validateItem(teacherId, item);
        }

        // 3. 建作业（组合包作业不写 case_id，病例挂在任务项上）
        Assignment a = new Assignment();
        a.setTeacherId(teacherId);
        a.setTitle(req.getTitle());
        a.setDescription(req.getDescription());
        a.setDeadline(req.getDeadline());
        a.setAllowLateSubmit(req.getAllowLateSubmit() == null ? Boolean.FALSE : req.getAllowLateSubmit());
        // 学习通式作业设置：定时发布 / 补交窗口 / 总分 / 公布策略 / 提交次数 / 乱序 / 查重
        a.setStartTime(req.getStartTime());
        a.setLateDeadline(req.getLateDeadline());
        a.setTotalScore(req.getTotalScore());
        a.setScorePublishMode(normalizePublishMode(req.getScorePublishMode(), "IMMEDIATE"));
        a.setAnswerPublishMode(normalizePublishMode(req.getAnswerPublishMode(), "AFTER_DEADLINE"));
        a.setShuffleQuestions(req.getShuffleQuestions() != null && req.getShuffleQuestions());
        a.setMaxAttempts(req.getMaxAttempts() == null || req.getMaxAttempts() < 1 ? 1 : req.getMaxAttempts());
        a.setPlagiarismCheck(req.getPlagiarismCheck() != null && req.getPlagiarismCheck());
        validateSchedule(a);
        a.setStatus(1);
        assignmentMapper.insert(a);

        // 4. 建目标班级
        List<AssignmentTargetClass> targets = req.getClassIds().stream().distinct().map(classId -> {
            AssignmentTargetClass target = new AssignmentTargetClass();
            target.setAssignmentId(a.getId());
            target.setClassId(classId);
            return target;
        }).toList();
        Db.saveBatch(targets);

        // 5. 建任务项（带排序）
        List<AssignmentItem> items = new ArrayList<>();
        int sort = 0;
        for (AssignmentCreateDTO.Item item : req.getItems()) {
            AssignmentItem ai = new AssignmentItem();
            ai.setAssignmentId(a.getId());
            ai.setItemType(item.getItemType().toUpperCase());
            ai.setTitle(defaultItemTitle(item));
            ai.setSortOrder(sort++);
            switch (ai.getItemType()) {
                case "CASE" -> {
                    ai.setCaseId(item.getCaseId());
                    ai.setAntiCheatVariables(item.getAntiCheatVariables());
                    ai.setRequireMedicalRecord(
                            item.getRequireMedicalRecord() == null ? Boolean.TRUE : item.getRequireMedicalRecord());
                    ai.setFormatRuleJson(item.getFormatRuleJson());
                }
                case "PRACTICE" -> ai.setQuestionIds(toJson(item.getQuestionIds()));
                case "READING" -> {
                    ai.setTextbookId(item.getTextbookId());
                    ai.setReadingScope(item.getReadingScope());
                }
                case "MATERIAL" -> ai.setLessonMaterialId(item.getLessonMaterialId());
                default -> throw new BizException(ResultCode.VALIDATION_FAILED, "不支持的任务项类型: " + item.getItemType());
            }
            items.add(ai);
        }
        Db.saveBatch(items);

        // 6. 为所选班级每个学生批量生成实例 + 任务项进度
        // 学生归属以 student_class_membership 多对多表为准（邀请码加入只写该表），
        // 并兜底并集 sys_user.class_id 遗留的旧数据，保证历史归属学生也能收到作业。
        Set<Long> studentIds = new LinkedHashSet<>();
        for (Long classId : req.getClassIds()) {
            membershipMapper.selectList(new LambdaQueryWrapper<StudentClassMembership>()
                            .eq(StudentClassMembership::getClassId, classId))
                    .forEach(m -> studentIds.add(m.getStudentId()));
        }
        userMapper.selectList(new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 0)
                        .eq(SysUser::getStatus, 0)
                        .in(SysUser::getClassId, req.getClassIds()))
                .forEach(u -> studentIds.add(u.getId()));
        List<SysUser> students = studentIds.isEmpty() ? List.of()
                : userMapper.selectList(new LambdaQueryWrapper<SysUser>()
                        .in(SysUser::getId, studentIds)
                        .eq(SysUser::getRole, 0)
                        .eq(SysUser::getStatus, 0));
        if (!students.isEmpty()) {
            List<AssignmentInstance> instances = students.stream().map(s -> {
                AssignmentInstance inst = new AssignmentInstance();
                inst.setAssignmentId(a.getId());
                inst.setStudentId(s.getId());
                inst.setStatus(0);
                return inst;
            }).collect(Collectors.toList());
            Db.saveBatch(instances);

            List<AssignmentItemProgress> progresses = new ArrayList<>();
            for (AssignmentInstance inst : instances) {
                for (AssignmentItem item : items) {
                    AssignmentItemProgress p = new AssignmentItemProgress();
                    p.setInstanceId(inst.getId());
                    p.setItemId(item.getId());
                    p.setStudentId(inst.getStudentId());
                    if ("CASE".equals(item.getItemType())) {
                        p.setCaseId(item.getCaseId());
                        p.setVariableSnapshotJson(
                                generateVariableSnapshot(item.getAntiCheatVariables(), inst.getStudentId()));
                    }
                    p.setStatus(0);
                    progresses.add(p);
                }
            }
            Db.saveBatch(progresses);
            log.info("教师{}创建组合作业{}，任务项{}个，学生实例{}条，任务项进度{}条",
                    teacherId, a.getId(), items.size(), instances.size(), progresses.size());
        }
        return a.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateSettings(Long assignmentId, AssignmentSettingsDTO req) {
        Long teacherId = UserContext.requireUserId();
        Assignment a = assignmentMapper.selectById(assignmentId);
        if (a == null || !teacherId.equals(a.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能修改本人发布的作业");
        }
        if (req.getDeadline() != null) {
            a.setDeadline(req.getDeadline());
        }
        if (req.getStartTime() != null) {
            a.setStartTime(req.getStartTime());
        }
        if (req.getAllowLateSubmit() != null) {
            a.setAllowLateSubmit(req.getAllowLateSubmit());
        }
        if (req.getLateDeadline() != null) {
            a.setLateDeadline(req.getLateDeadline());
        }
        if (req.getTotalScore() != null) {
            a.setTotalScore(req.getTotalScore());
        }
        if (req.getScorePublishMode() != null) {
            a.setScorePublishMode(normalizePublishMode(req.getScorePublishMode(), "IMMEDIATE"));
        }
        if (req.getAnswerPublishMode() != null) {
            a.setAnswerPublishMode(normalizePublishMode(req.getAnswerPublishMode(), "AFTER_DEADLINE"));
        }
        if (req.getShuffleQuestions() != null) {
            a.setShuffleQuestions(req.getShuffleQuestions());
        }
        if (req.getMaxAttempts() != null) {
            a.setMaxAttempts(req.getMaxAttempts() < 1 ? 1 : req.getMaxAttempts());
        }
        if (req.getPlagiarismCheck() != null) {
            a.setPlagiarismCheck(req.getPlagiarismCheck());
        }
        validateSchedule(a);
        assignmentMapper.updateById(a);
    }

    /** 发布时间线校验：开始 < 截止 < 补交截止 */
    private void validateSchedule(Assignment a) {
        if (a.getStartTime() != null && a.getDeadline() != null && !a.getStartTime().isBefore(a.getDeadline())) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "开始时间必须早于截止时间");
        }
        if (Boolean.TRUE.equals(a.getAllowLateSubmit())) {
            if (a.getLateDeadline() == null) {
                throw new BizException(ResultCode.VALIDATION_FAILED, "允许补交时必须填写补交截止时间");
            }
            if (a.getDeadline() != null && !a.getLateDeadline().isAfter(a.getDeadline())) {
                throw new BizException(ResultCode.VALIDATION_FAILED, "补交截止时间必须晚于截止时间");
            }
        }
    }

    /** 公布方式归一：非法值回落默认值，避免脏数据导致前端判断失效 */
    private String normalizePublishMode(String mode, String fallback) {
        if (mode == null || mode.isBlank()) {
            return fallback;
        }
        return switch (mode.trim().toUpperCase()) {
            case "IMMEDIATE", "AFTER_DEADLINE", "MANUAL" -> mode.trim().toUpperCase();
            default -> fallback;
        };
    }

    /** 校验单个任务项的内容归属 */
    private void validateItem(Long teacherId, AssignmentCreateDTO.Item item) {
        String type = item.getItemType() == null ? "" : item.getItemType().toUpperCase();
        switch (type) {
            case "CASE" -> {
                if (item.getCaseId() == null) {
                    throw new BizException(ResultCode.VALIDATION_FAILED, "病例任务项必须选择病例");
                }
                SpCaseConfig c = caseMapper.selectById(item.getCaseId());
                if (c == null) {
                    throw new BizException(ResultCode.CASE_NOT_FOUND);
                }
                boolean mine = teacherId.equals(c.getCreatorId());
                boolean publicApproved = c.getAdminAuditStatus() != null && c.getAdminAuditStatus() == 2;
                if (!mine && !publicApproved) {
                    throw new BizException(ResultCode.FORBIDDEN, "只能使用本人病例或病例广场已过审的病例");
                }
            }
            case "PRACTICE" -> {
                List<Long> ids = item.getQuestionIds();
                if (ids == null || ids.isEmpty()) {
                    throw new BizException(ResultCode.VALIDATION_FAILED, "练习任务项至少选择一道题");
                }
                // 本人题目（任意审核状态，自出题直接可用）或平台已过审题目
                long count = questionMapper.selectCount(new LambdaQueryWrapper<PracticeQuestion>()
                        .in(PracticeQuestion::getId, ids)
                        .and(w -> w.eq(PracticeQuestion::getSubmitterId, teacherId)
                                .or().eq(PracticeQuestion::getAdminAuditStatus, 2)));
                if (count != ids.size()) {
                    throw new BizException(ResultCode.FORBIDDEN, "练习题只能使用本人题库或平台已过审的题目");
                }
            }
            case "READING" -> {
                if (item.getTextbookId() == null) {
                    throw new BizException(ResultCode.VALIDATION_FAILED, "阅读任务项必须选择教材");
                }
                Textbook t = textbookMapper.selectById(item.getTextbookId());
                if (t == null) {
                    throw new BizException(ResultCode.VALIDATION_FAILED, "教材不存在");
                }
                boolean mine = teacherId.equals(t.getCreatorId());
                boolean published = t.getStatus() != null && t.getStatus() == 1;
                if (!mine && !published) {
                    throw new BizException(ResultCode.FORBIDDEN, "只能使用本人上传或已上架的教材");
                }
            }
            case "MATERIAL" -> {
                if (item.getLessonMaterialId() == null) {
                    throw new BizException(ResultCode.VALIDATION_FAILED, "资料任务项必须选择备课资料");
                }
                LessonMaterial m = lessonMaterialMapper.selectById(item.getLessonMaterialId());
                if (m == null || (m.getIsDeleted() != null && m.getIsDeleted() == 1)) {
                    throw new BizException(ResultCode.VALIDATION_FAILED, "备课资料不存在或已删除");
                }
                // 材料必须挂在本教师的备课下
                LessonPlan plan = lessonPlanMapper.selectById(m.getLessonId());
                if (plan == null || !teacherId.equals(plan.getTeacherId())) {
                    throw new BizException(ResultCode.FORBIDDEN, "只能使用本人备课下的资料");
                }
            }
            default -> throw new BizException(ResultCode.VALIDATION_FAILED, "不支持的任务项类型: " + item.getItemType());
        }
    }

    /** 任务项默认标题（未填标题时按类型自动生成） */
    private String defaultItemTitle(AssignmentCreateDTO.Item item) {
        if (item.getTitle() != null && !item.getTitle().isBlank()) {
            return item.getTitle();
        }
        return switch (item.getItemType().toUpperCase()) {
            case "CASE" -> {
                SpCaseConfig c = caseMapper.selectById(item.getCaseId());
                yield "病例问诊" + (c != null ? " · " + c.getTitle() : "");
            }
            case "PRACTICE" -> "基础练习(" + (item.getQuestionIds() == null ? 0 : item.getQuestionIds().size()) + "题)";
            case "READING" -> {
                Textbook t = textbookMapper.selectById(item.getTextbookId());
                yield "阅读任务" + (t != null ? " · " + t.getTitle() : "");
            }
            case "MATERIAL" -> {
                LessonMaterial m = lessonMaterialMapper.selectById(item.getLessonMaterialId());
                yield "学习资料" + (m != null ? " · " + m.getTitle() : "");
            }
            default -> "任务";
        };
    }

    @Override
    public List<TeacherAssignmentListVO> list() {
        Long teacherId = UserContext.requireUserId();
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>()
                        .eq(Assignment::getTeacherId, teacherId)
                        .orderByDesc(Assignment::getCreatedAt));
        if (assignments.isEmpty()) return List.of();

        List<Long> ids = assignments.stream().map(Assignment::getId).toList();
        List<AssignmentTargetClass> targets = targetClassMapper.selectList(
                new LambdaQueryWrapper<AssignmentTargetClass>().in(AssignmentTargetClass::getAssignmentId, ids));
        Map<Long, TeachingClass> classMap = classMapper.selectBatchIds(
                        targets.stream().map(AssignmentTargetClass::getClassId).distinct().toList())
                .stream().collect(Collectors.toMap(TeachingClass::getId, item -> item));
        Map<Long, List<AssignmentTargetClass>> targetsByAssignment = targets.stream()
                .collect(Collectors.groupingBy(AssignmentTargetClass::getAssignmentId));
        List<AssignmentInstance> instances = instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>().in(AssignmentInstance::getAssignmentId, ids));
        Map<Long, List<AssignmentInstance>> instancesByAssignment = instances.stream()
                .collect(Collectors.groupingBy(AssignmentInstance::getAssignmentId));

        // 任务项（组合包）
        List<AssignmentItem> items = itemMapper.selectList(
                new LambdaQueryWrapper<AssignmentItem>().in(AssignmentItem::getAssignmentId, ids));
        Map<Long, List<AssignmentItem>> itemsByAssignment = items.stream()
                .collect(Collectors.groupingBy(AssignmentItem::getAssignmentId));
        Map<Long, String> caseTitleMap = loadCaseTitles(items);
        Map<Long, String> textbookTitleMap = loadTextbookTitles(items);

        // 存量作业病例标题
        List<Long> legacyCaseIds = assignments.stream().map(Assignment::getCaseId)
                .filter(Objects::nonNull).distinct().toList();
        Map<Long, String> legacyCaseTitleMap = new HashMap<>();
        if (!legacyCaseIds.isEmpty()) {
            for (SpCaseConfig c : caseMapper.selectList(
                    new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, legacyCaseIds))) {
                legacyCaseTitleMap.put(c.getId(), c.getTitle());
            }
        }

        return assignments.stream().map(a -> {
            List<AssignmentInstance> rows = instancesByAssignment.getOrDefault(a.getId(), List.of());
            List<AssignmentItem> myItems = itemsByAssignment.getOrDefault(a.getId(), List.of());
            long studentCount = rows.size();
            long submitted;
            List<AssignmentItemVO> itemVOs = null;
            if (!myItems.isEmpty()) {
                // 组合包:全部任务项完成才算提交
                List<Long> instIds = rows.stream().map(AssignmentInstance::getId).toList();
                Map<Long, List<AssignmentItemProgress>> progByInst = instIds.isEmpty() ? Map.of()
                        : loadProgressByInstance(instIds);
                submitted = rows.stream().filter(inst -> allItemsDone(progByInst.getOrDefault(inst.getId(), List.of()),
                        myItems.size())).count();
                itemVOs = myItems.stream().map(item -> toItemVO(item, caseTitleMap, textbookTitleMap))
                        .collect(Collectors.toList());
            } else {
                // 存量:状态>=2 算提交
                submitted = rows.stream().filter(item -> item.getStatus() != null && item.getStatus() >= 2).count();
            }
            List<String> classNames = targetsByAssignment.getOrDefault(a.getId(), List.of()).stream()
                    .map(AssignmentTargetClass::getClassId).map(classMap::get).filter(Objects::nonNull)
                    .map(TeachingClass::getName).toList();
            String caseTitle = legacyCaseTitleMap.getOrDefault(a.getCaseId(), "");
            return TeacherAssignmentListVO.builder()
                    .id(a.getId()).title(a.getTitle()).caseId(a.getCaseId())
                    .caseTitle(caseTitle).deadline(a.getDeadline())
                    .startTime(a.getStartTime()).allowLateSubmit(a.getAllowLateSubmit())
                    .lateDeadline(a.getLateDeadline()).totalScore(a.getTotalScore())
                    .scorePublishMode(a.getScorePublishMode()).answerPublishMode(a.getAnswerPublishMode())
                    .shuffleQuestions(a.getShuffleQuestions()).maxAttempts(a.getMaxAttempts())
                    .plagiarismCheck(a.getPlagiarismCheck())
                    .status(a.getStatus()).requireMedicalRecord(a.getRequireMedicalRecord())
                    .antiCheatVariables(a.getAntiCheatVariables()).classNames(classNames)
                    .submittedCount(submitted).studentCount(studentCount).items(itemVOs).build();
        }).toList();
    }

    @Override
    public List<TeachingClassVO> classes() {
        Long teacherId = UserContext.requireUserId();
        List<Long> ids = authorizationMapper.selectList(
                        new LambdaQueryWrapper<TeacherClassAuthorization>()
                                .eq(TeacherClassAuthorization::getTeacherId, teacherId))
                .stream().map(TeacherClassAuthorization::getClassId).toList();
        if (ids.isEmpty()) return List.of();
        return classMapper.selectBatchIds(ids).stream()
                .filter(item -> item.getStatus() != null && item.getStatus() == 0)
                .map(item -> {
                    Long count = membershipMapper.selectCount(
                            new LambdaQueryWrapper<StudentClassMembership>()
                                    .eq(StudentClassMembership::getClassId, item.getId()));
                    return TeachingClassVO.builder().id(item.getId()).name(item.getName())
                            .grade(item.getGrade()).studentCount(count)
                            .build();
                }).toList();
    }

    @Override
    public AssignmentProgressVO progress(Long assignmentId) {
        Long teacherId = UserContext.requireUserId();
        Assignment a = assignmentMapper.selectById(assignmentId);
        if (a == null) {
            throw new BizException(ResultCode.ASSIGNMENT_NOT_FOUND);
        }
        if (!teacherId.equals(a.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN);
        }

        List<AssignmentInstance> instances = instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>()
                        .eq(AssignmentInstance::getAssignmentId, assignmentId));
        List<AssignmentItem> items = itemMapper.selectList(
                new LambdaQueryWrapper<AssignmentItem>()
                        .eq(AssignmentItem::getAssignmentId, assignmentId)
                        .orderByAsc(AssignmentItem::getSortOrder));

        Map<String, Long> stats;
        List<AssignmentItemStatVO> itemStats = null;
        List<StudentProgressVO> students;

        List<Long> studentIds = instances.stream().map(AssignmentInstance::getStudentId)
                .filter(Objects::nonNull).distinct().collect(Collectors.toList());
        Map<Long, String> nameMap = new HashMap<>();
        if (!studentIds.isEmpty()) {
            for (SysUser u : userMapper.selectList(
                    new LambdaQueryWrapper<SysUser>().in(SysUser::getId, studentIds))) {
                nameMap.put(u.getId(), u.getRealName());
            }
        }

        if (!items.isEmpty()) {
            // 组合包:按任务项进度统计
            List<Long> instIds = instances.stream().map(AssignmentInstance::getId).toList();
            Map<Long, List<AssignmentItemProgress>> progByInst =
                    instIds.isEmpty() ? Map.of() : loadProgressByInstance(instIds);
            List<AssignmentItemProgress> allProg = instIds.isEmpty() ? List.of()
                    : progressMapper.selectList(new LambdaQueryWrapper<AssignmentItemProgress>()
                            .in(AssignmentItemProgress::getInstanceId, instIds));

            // 作业级聚合
            long notStarted = 0, inProgress = 0, completed = 0;
            for (AssignmentInstance inst : instances) {
                List<AssignmentItemProgress> ps = progByInst.getOrDefault(inst.getId(), List.of());
                if (allItemsDone(ps, items.size())) completed++;
                else if (ps.stream().anyMatch(p -> p.getStatus() != null && p.getStatus() > 0)) inProgress++;
                else notStarted++;
            }
            stats = new LinkedHashMap<>();
            stats.put("notStarted", notStarted);
            stats.put("inProgress", inProgress);
            stats.put("formatRejected", 0L);
            stats.put("aiReviewing", 0L);
            stats.put("pendingReview", 0L);
            stats.put("completed", completed);

            // 任务项统计
            Map<Long, List<AssignmentItemProgress>> progByItem = allProg.stream()
                    .collect(Collectors.groupingBy(AssignmentItemProgress::getItemId));
            Map<Long, String> caseTitleMap = loadCaseTitles(items);
            Map<Long, String> textbookTitleMap = loadTextbookTitles(items);
            itemStats = items.stream().map(item -> {
                List<AssignmentItemProgress> ps = progByItem.getOrDefault(item.getId(), List.of());
                long done = ps.stream().filter(p -> p.getStatus() != null && p.getStatus() == 5).count();
                long pending = ps.stream().filter(p -> p.getStatus() != null && p.getStatus() == 4).count();
                Double avg = null;
                if ("PRACTICE".equals(item.getItemType())) {
                    List<Double> scores = ps.stream().map(p -> p.getScore() == null ? null : p.getScore().doubleValue())
                            .filter(Objects::nonNull).toList();
                    if (!scores.isEmpty()) {
                        avg = scores.stream().mapToDouble(Double::doubleValue).average().orElse(0);
                        avg = Math.round(avg * 10.0) / 10.0;
                    }
                }
                return AssignmentItemStatVO.builder()
                        .itemId(item.getId())
                        .itemType(item.getItemType())
                        .title(item.getTitle())
                        .total((long) instances.size())
                        .completed(done)
                        .pendingReview("CASE".equals(item.getItemType()) ? pending : null)
                        .avgScore(avg)
                        .build();
            }).collect(Collectors.toList());

            // 学生明细
            students = instances.stream().map(inst -> {
                List<AssignmentItemProgress> ps = progByInst.getOrDefault(inst.getId(), List.of());
                int st;
                if (allItemsDone(ps, items.size())) st = 5;
                else if (ps.stream().anyMatch(p -> p.getStatus() != null && p.getStatus() > 0)) st = 1;
                else st = 0;
                return StudentProgressVO.builder()
                        .instanceId(inst.getId()).studentId(inst.getStudentId())
                        .studentName(nameMap.getOrDefault(inst.getStudentId(), ""))
                        .status(st).submitTime(inst.getSubmitTime()).build();
            }).collect(Collectors.toList());
        } else {
            // 存量:原状态统计
            long notStarted = 0, inProgress = 0, formatRejected = 0, aiReviewing = 0, pendingReview = 0, completed = 0;
            for (AssignmentInstance inst : instances) {
                int st = inst.getStatus() == null ? 0 : inst.getStatus();
                switch (st) {
                    case 0 -> notStarted++;
                    case 1 -> inProgress++;
                    case 2 -> formatRejected++;
                    case 3 -> aiReviewing++;
                    case 4 -> pendingReview++;
                    case 5 -> completed++;
                    default -> { }
                }
            }
            stats = new LinkedHashMap<>();
            stats.put("notStarted", notStarted);
            stats.put("inProgress", inProgress);
            stats.put("formatRejected", formatRejected);
            stats.put("aiReviewing", aiReviewing);
            stats.put("pendingReview", pendingReview);
            stats.put("completed", completed);
            students = instances.stream().map(inst -> StudentProgressVO.builder()
                    .instanceId(inst.getId()).studentId(inst.getStudentId())
                    .studentName(nameMap.getOrDefault(inst.getStudentId(), ""))
                    .status(inst.getStatus()).submitTime(inst.getSubmitTime()).build())
                    .collect(Collectors.toList());
        }

        return AssignmentProgressVO.builder()
                .assignmentId(a.getId())
                .assignmentTitle(a.getTitle())
                .statusStats(stats)
                .itemStats(itemStats)
                .students(students)
                .build();
    }

    // ========= 辅助方法 =========

    private boolean allItemsDone(List<AssignmentItemProgress> ps, int itemCount) {
        if (itemCount == 0) return false;
        if (ps.size() < itemCount) return false;
        return ps.stream().allMatch(p -> p.getStatus() != null && p.getStatus() == 5);
    }

    private Map<Long, List<AssignmentItemProgress>> loadProgressByInstance(List<Long> instanceIds) {
        List<AssignmentItemProgress> all = progressMapper.selectList(
                new LambdaQueryWrapper<AssignmentItemProgress>()
                        .in(AssignmentItemProgress::getInstanceId, instanceIds));
        return all.stream().collect(Collectors.groupingBy(AssignmentItemProgress::getInstanceId));
    }

    private Map<Long, String> loadCaseTitles(List<AssignmentItem> items) {
        List<Long> caseIds = items.stream().map(AssignmentItem::getCaseId)
                .filter(Objects::nonNull).distinct().toList();
        Map<Long, String> map = new HashMap<>();
        if (!caseIds.isEmpty()) {
            for (SpCaseConfig c : caseMapper.selectList(
                    new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, caseIds))) {
                map.put(c.getId(), c.getTitle());
            }
        }
        return map;
    }

    private Map<Long, String> loadTextbookTitles(List<AssignmentItem> items) {
        List<Long> ids = items.stream().map(AssignmentItem::getTextbookId)
                .filter(Objects::nonNull).distinct().toList();
        Map<Long, String> map = new HashMap<>();
        if (!ids.isEmpty()) {
            for (Textbook t : textbookMapper.selectList(
                    new LambdaQueryWrapper<Textbook>().in(Textbook::getId, ids))) {
                map.put(t.getId(), t.getTitle());
            }
        }
        return map;
    }

    private AssignmentItemVO toItemVO(AssignmentItem item, Map<Long, String> caseTitleMap,
                                      Map<Long, String> textbookTitleMap) {
        List<Long> qids = null;
        Integer qCount = null;
        if ("PRACTICE".equals(item.getItemType()) && item.getQuestionIds() != null) {
            try {
                qids = objectMapper.readValue(item.getQuestionIds(),
                        objectMapper.getTypeFactory().constructCollectionType(List.class, Long.class));
                qCount = qids.size();
            } catch (Exception e) {
                log.warn("解析 questionIds 失败: itemId={}", item.getId());
            }
        }
        return AssignmentItemVO.builder()
                .id(item.getId()).assignmentId(item.getAssignmentId())
                .itemType(item.getItemType()).title(item.getTitle()).sortOrder(item.getSortOrder())
                .caseId(item.getCaseId())
                .caseTitle(item.getCaseId() == null ? null : caseTitleMap.getOrDefault(item.getCaseId(), ""))
                .questionIds(qids).questionCount(qCount)
                .textbookId(item.getTextbookId())
                .textbookTitle(item.getTextbookId() == null ? null
                        : textbookTitleMap.getOrDefault(item.getTextbookId(), ""))
                .readingScope(item.getReadingScope())
                .build();
    }

    /**
     * 根据教师配置的 antiCheatVariables 模板，生成该学生唯一的变量快照。
     * 在模板 JSON 中添加 _studentSeed 字段，使每个学生拥有略微不同的变量副本。
     */
    private String generateVariableSnapshot(String antiCheatVars, Long studentId) {
        try {
            JsonNode root = objectMapper.readTree(antiCheatVars);
            if (root.isObject()) {
                ObjectNode copy = (ObjectNode) root.deepCopy();
                copy.put("_studentSeed", studentId % 10000);
                return objectMapper.writeValueAsString(copy);
            }
        } catch (Exception e) {
            log.warn("解析 antiCheatVariables 失败，使用空快照: {}", e.getMessage());
        }
        return "{}";
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "参数序列化失败");
        }
    }
}
