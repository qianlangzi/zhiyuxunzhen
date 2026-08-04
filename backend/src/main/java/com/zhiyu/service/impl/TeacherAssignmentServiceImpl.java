package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.toolkit.Db;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.entity.TeacherClassAuthorization;
import com.zhiyu.entity.AssignmentTargetClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.mapper.TeacherClassAuthorizationMapper;
import com.zhiyu.mapper.AssignmentTargetClassMapper;
import com.zhiyu.service.TeacherAssignmentService;
import com.zhiyu.service.dto.AssignmentCreateDTO;
import com.zhiyu.vo.AssignmentProgressVO;
import com.zhiyu.vo.StudentProgressVO;
import com.zhiyu.vo.TeacherAssignmentListVO;
import com.zhiyu.vo.TeachingClassVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * 教师作业服务实现（PRD 4.3）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherAssignmentServiceImpl implements TeacherAssignmentService {

    private final AssignmentMapper assignmentMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final SpCaseConfigMapper caseMapper;
    private final SysUserMapper userMapper;
    private final TeachingClassMapper classMapper;
    private final TeacherClassAuthorizationMapper authorizationMapper;
    private final AssignmentTargetClassMapper targetClassMapper;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long create(AssignmentCreateDTO req) {
        Long teacherId = UserContext.requireUserId();
        SpCaseConfig c = caseMapper.selectById(req.getCaseId());
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        if (!teacherId.equals(c.getCreatorId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能使用本人创建的病例布置作业");
        }

        List<Long> authorizedClassIds = authorizationMapper.selectList(
                        new LambdaQueryWrapper<TeacherClassAuthorization>()
                                .eq(TeacherClassAuthorization::getTeacherId, teacherId))
                .stream().map(TeacherClassAuthorization::getClassId).toList();
        if (!authorizedClassIds.containsAll(req.getClassIds())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能向已授权班级布置作业");
        }

        Assignment a = new Assignment();
        a.setTeacherId(teacherId);
        a.setCaseId(req.getCaseId());
        a.setTitle(req.getTitle());
        a.setDescription(req.getDescription());
        a.setRequireMedicalRecord(req.getRequireMedicalRecord() == null ? Boolean.TRUE : req.getRequireMedicalRecord());
        a.setFormatRuleJson(req.getFormatRuleJson());
        a.setAntiCheatVariables(req.getAntiCheatVariables());
        a.setDeadline(req.getDeadline());
        a.setAllowLateSubmit(req.getAllowLateSubmit() == null ? Boolean.FALSE : req.getAllowLateSubmit());
        a.setStatus(1);
        assignmentMapper.insert(a);

        List<AssignmentTargetClass> targets = req.getClassIds().stream().distinct().map(classId -> {
            AssignmentTargetClass target = new AssignmentTargetClass();
            target.setAssignmentId(a.getId());
            target.setClassId(classId);
            return target;
        }).toList();
        Db.saveBatch(targets);

        // 为所选班级的每个学生批量生成作业实例（避免逐条 insert 性能差）
        List<SysUser> students = userMapper.selectList(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 0)
                        .eq(SysUser::getStatus, 0)
                        .in(SysUser::getClassId, req.getClassIds()));
        if (!students.isEmpty()) {
            String antiCheatVars = a.getAntiCheatVariables();
            boolean hasAntiCheat = antiCheatVars != null && !antiCheatVars.isEmpty() && !"{}".equals(antiCheatVars);
            List<AssignmentInstance> instances = students.stream().map(s -> {
                AssignmentInstance inst = new AssignmentInstance();
                inst.setAssignmentId(a.getId());
                inst.setStudentId(s.getId());
                inst.setCaseId(req.getCaseId());
                inst.setVariableSnapshotJson(hasAntiCheat ? generateVariableSnapshot(antiCheatVars, s.getId()) : "{}");
                inst.setStatus(0);
                return inst;
            }).collect(Collectors.toList());
            Db.saveBatch(instances);
        }
        log.info("教师{}创建作业{}，生成{}个学生实例", teacherId, a.getId(), students.size());
        return a.getId();
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
                new LambdaQueryWrapper<AssignmentTargetClass>()
                        .in(AssignmentTargetClass::getAssignmentId, ids));
        Map<Long, TeachingClass> classMap = classMapper.selectBatchIds(
                        targets.stream().map(AssignmentTargetClass::getClassId).distinct().toList())
                .stream().collect(Collectors.toMap(TeachingClass::getId, item -> item));
        Map<Long, List<AssignmentTargetClass>> targetsByAssignment = targets.stream()
                .collect(Collectors.groupingBy(AssignmentTargetClass::getAssignmentId));
        List<AssignmentInstance> instances = instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>().in(AssignmentInstance::getAssignmentId, ids));
        Map<Long, List<AssignmentInstance>> instancesByAssignment = instances.stream()
                .collect(Collectors.groupingBy(AssignmentInstance::getAssignmentId));
        Map<Long, SpCaseConfig> cases = caseMapper.selectBatchIds(
                        assignments.stream().map(Assignment::getCaseId).distinct().toList())
                .stream().collect(Collectors.toMap(SpCaseConfig::getId, item -> item));
        return assignments.stream().map(a -> {
            List<AssignmentInstance> rows = instancesByAssignment.getOrDefault(a.getId(), List.of());
            long submitted = rows.stream().filter(item -> item.getStatus() != null && item.getStatus() >= 2).count();
            List<String> classNames = targetsByAssignment.getOrDefault(a.getId(), List.of()).stream()
                    .map(AssignmentTargetClass::getClassId).map(classMap::get).filter(Objects::nonNull)
                    .map(TeachingClass::getName).toList();
            SpCaseConfig c = cases.get(a.getCaseId());
            return TeacherAssignmentListVO.builder()
                    .id(a.getId()).title(a.getTitle()).caseId(a.getCaseId())
                    .caseTitle(c == null ? "" : c.getTitle()).deadline(a.getDeadline())
                    .status(a.getStatus()).requireMedicalRecord(a.getRequireMedicalRecord())
                    .antiCheatVariables(a.getAntiCheatVariables()).classNames(classNames)
                    .submittedCount(submitted).studentCount((long) rows.size()).build();
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
                .map(item -> TeachingClassVO.builder().id(item.getId()).name(item.getName())
                        .grade(item.getGrade()).studentCount(userMapper.selectCount(
                                new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, 0)
                                        .eq(SysUser::getClassId, item.getId()).eq(SysUser::getStatus, 0)))
                        .build()).toList();
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
                new LambdaQueryWrapper<AssignmentInstance>().eq(AssignmentInstance::getAssignmentId, assignmentId));

        // 各状态学生数统计：0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成
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
        Map<String, Long> stats = new LinkedHashMap<>();
        stats.put("notStarted", notStarted);
        stats.put("inProgress", inProgress);
        stats.put("formatRejected", formatRejected);
        stats.put("aiReviewing", aiReviewing);
        stats.put("pendingReview", pendingReview);
        stats.put("completed", completed);

        // 学生明细（补全姓名）
        List<Long> studentIds = instances.stream()
                .map(AssignmentInstance::getStudentId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, String> nameMap = new HashMap<>();
        if (!studentIds.isEmpty()) {
            List<SysUser> users = userMapper.selectList(
                    new LambdaQueryWrapper<SysUser>().in(SysUser::getId, studentIds));
            for (SysUser u : users) {
                nameMap.put(u.getId(), u.getRealName());
            }
        }
        List<StudentProgressVO> students = instances.stream().map(inst -> StudentProgressVO.builder()
                .instanceId(inst.getId())
                .studentId(inst.getStudentId())
                .studentName(nameMap.getOrDefault(inst.getStudentId(), ""))
                .status(inst.getStatus())
                .submitTime(inst.getSubmitTime())
                .build()).collect(Collectors.toList());

        return AssignmentProgressVO.builder()
                .assignmentId(a.getId())
                .assignmentTitle(a.getTitle())
                .statusStats(stats)
                .students(students)
                .build();
    }
}
