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
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.TeacherAssignmentService;
import com.zhiyu.service.dto.AssignmentCreateDTO;
import com.zhiyu.vo.AssignmentProgressVO;
import com.zhiyu.vo.StudentProgressVO;
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

        // 为所选班级的每个学生批量生成作业实例（避免逐条 insert 性能差）
        List<SysUser> students = userMapper.selectList(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 0)
                        .eq(SysUser::getStatus, 0)
                        .in(SysUser::getClassId, req.getClassIds()));
        if (!students.isEmpty()) {
            List<AssignmentInstance> instances = students.stream().map(s -> {
                AssignmentInstance inst = new AssignmentInstance();
                inst.setAssignmentId(a.getId());
                inst.setStudentId(s.getId());
                inst.setCaseId(req.getCaseId());
                inst.setVariableSnapshotJson("{}");
                inst.setStatus(0);
                return inst;
            }).collect(Collectors.toList());
            Db.saveBatch(instances);
        }
        log.info("教师{}创建作业{}，生成{}个学生实例", teacherId, a.getId(), students.size());
        return a.getId();
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
