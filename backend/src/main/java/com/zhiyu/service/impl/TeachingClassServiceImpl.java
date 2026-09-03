package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentTargetClass;
import com.zhiyu.entity.LessonMaterial;
import com.zhiyu.entity.LessonPlan;
import com.zhiyu.entity.LessonPublish;
import com.zhiyu.entity.StudentClassMembership;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.TeacherClassAuthorization;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.AssignmentTargetClassMapper;
import com.zhiyu.mapper.LessonMaterialMapper;
import com.zhiyu.mapper.LessonPlanMapper;
import com.zhiyu.mapper.LessonPublishMapper;
import com.zhiyu.mapper.StudentClassMembershipMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TeacherClassAuthorizationMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.service.TeachingClassService;
import com.zhiyu.service.dto.TeachingClassCreateDTO;
import com.zhiyu.service.dto.TeachingClassJoinDTO;
import com.zhiyu.vo.MyClassVO;
import com.zhiyu.vo.StudentClassDetailVO;
import com.zhiyu.vo.TeachingClassMemberVO;
import com.zhiyu.vo.TeachingClassVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ThreadLocalRandom;
import java.time.LocalDateTime;

/**
 * 班级管理实现：教师自建（归属 teacher_id）+ 管理员预置授权并存。
 */
@Service
@RequiredArgsConstructor
public class TeachingClassServiceImpl implements TeachingClassService {

    private static final int INVITE_LEN = 6;

    private final TeachingClassMapper classMapper;
    private final TeacherClassAuthorizationMapper authorizationMapper;
    private final SysUserMapper userMapper;
    private final StudentClassMembershipMapper membershipMapper;
    private final LessonPublishMapper publishMapper;
    private final LessonPlanMapper lessonPlanMapper;
    private final LessonMaterialMapper materialMapper;
    private final AssignmentMapper assignmentMapper;
    private final AssignmentTargetClassMapper assignmentTargetClassMapper;
    private final AssignmentInstanceMapper assignmentInstanceMapper;

    @Override
    public List<TeachingClassVO> myClasses() {
        Long tid = UserContext.requireUserId();
        Set<Long> ids = new HashSet<>();
        classMapper.selectList(new LambdaQueryWrapper<TeachingClass>()
                        .eq(TeachingClass::getTeacherId, tid))
                .forEach(c -> ids.add(c.getId()));
        authorizationMapper.selectList(new LambdaQueryWrapper<TeacherClassAuthorization>()
                        .eq(TeacherClassAuthorization::getTeacherId, tid))
                .forEach(a -> ids.add(a.getClassId()));
        if (ids.isEmpty()) return List.of();
        List<TeachingClass> list = new ArrayList<>(classMapper.selectBatchIds(ids));
        list.sort((a, b) -> {
            // 已手动排序（sort_order>0）的班级按序号置前，未排序的保持原相对顺序
            int ao = a.getSortOrder() == null ? 0 : a.getSortOrder();
            int bo = b.getSortOrder() == null ? 0 : b.getSortOrder();
            if (ao != bo) return (ao == 0 ? Integer.MAX_VALUE : ao)
                    - (bo == 0 ? Integer.MAX_VALUE : bo);
            boolean aOwn = Objects.equals(a.getTeacherId(), tid);
            boolean bOwn = Objects.equals(b.getTeacherId(), tid);
            if (aOwn != bOwn) return aOwn ? -1 : 1;
            return b.getId().compareTo(a.getId());
        });
        return list.stream()
                .filter(c -> c.getStatus() != null && c.getStatus() == 0)
                .map(this::toVO)
                .toList();
    }

    @Override
    public TeachingClassVO detail(Long classId) {
        TeachingClass tc = requireClass(classId);
        requireReadable(tc);
        return toVO(tc);
    }

    @Override
    @Transactional
    public TeachingClassVO create(TeachingClassCreateDTO req) {
        Long tid = UserContext.requireUserId();
        String name = req.getName().trim();
        String grade = req.getGrade() == null ? null : req.getGrade().trim();
        Long dup = classMapper.selectCount(new LambdaQueryWrapper<TeachingClass>()
                .eq(TeachingClass::getName, name)
                .eq(grade == null, TeachingClass::getGrade, grade)
                .eq(TeachingClass::getStatus, 0));
        if (dup != null && dup > 0) {
            throw new BizException(ResultCode.CLASS_NAME_EXISTS);
        }
        TeachingClass tc = new TeachingClass();
        tc.setName(name);
        tc.setGrade(grade);
        tc.setTeacherId(tid);
        tc.setStatus(0);
        tc.setInviteCode(uniqueInviteCode());
        classMapper.insert(tc);
        TeacherClassAuthorization auth = new TeacherClassAuthorization();
        auth.setTeacherId(tid);
        auth.setClassId(tc.getId());
        authorizationMapper.insert(auth);
        return toVO(tc);
    }

    @Override
    @Transactional
    public TeachingClassVO rename(Long classId, TeachingClassCreateDTO req) {
        Long tid = UserContext.requireUserId();
        TeachingClass tc = requireClass(classId);
        requireOwner(tc, tid);
        String name = req.getName().trim();
        Long dup = classMapper.selectCount(new LambdaQueryWrapper<TeachingClass>()
                .eq(TeachingClass::getName, name)
                .eq(req.getGrade() == null || req.getGrade().isBlank(), TeachingClass::getGrade, req.getGrade())
                .eq(TeachingClass::getStatus, 0)
                .ne(TeachingClass::getId, classId));
        if (dup != null && dup > 0) {
            throw new BizException(ResultCode.CLASS_NAME_EXISTS);
        }
        tc.setName(name);
        if (req.getGrade() != null && !req.getGrade().isBlank()) {
            tc.setGrade(req.getGrade().trim());
        }
        classMapper.updateById(tc);
        return toVO(tc);
    }

    @Override
    @Transactional
    public void dissolve(Long classId) {
        Long tid = UserContext.requireUserId();
        TeachingClass tc = requireClass(classId);
        requireOwner(tc, tid);
        tc.setStatus(1);
        classMapper.updateById(tc);
        // 清空该班学生的班级归属（多对多成员表），避免悬空引用
        membershipMapper.delete(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getClassId, classId));
        // 移除该班相关的教师授权
        authorizationMapper.delete(new LambdaQueryWrapper<TeacherClassAuthorization>()
                .eq(TeacherClassAuthorization::getClassId, classId));
    }

    @Override
    public List<TeachingClassMemberVO> members(Long classId) {
        TeachingClass tc = requireClass(classId);
        requireReadable(tc);
        List<Long> studentIds = membershipMapper.selectList(
                        new LambdaQueryWrapper<StudentClassMembership>()
                                .eq(StudentClassMembership::getClassId, classId))
                .stream()
                .map(StudentClassMembership::getStudentId)
                .toList();
        if (studentIds.isEmpty()) return List.of();
        return userMapper.selectList(new LambdaQueryWrapper<SysUser>()
                        .in(SysUser::getId, studentIds)
                        .eq(SysUser::getRole, 0)
                        .eq(SysUser::getStatus, 0)
                        .orderByAsc(SysUser::getId))
                .stream()
                .map(u -> TeachingClassMemberVO.builder()
                        .studentId(u.getId())
                        .username(u.getUsername())
                        .realName(u.getRealName())
                        .schoolName(u.getSchoolName())
                        .grade(u.getGrade())
                        .className(u.getClassName())
                        .build())
                .toList();
    }

    @Override
    @Transactional
    public void sortOrder(List<Long> classIds) {
        Long tid = UserContext.requireUserId();
        if (classIds == null || classIds.isEmpty()) return;
        // 只允许排序当前教师可见（自建或授权）的班级
        Set<Long> mine = new HashSet<>();
        classMapper.selectList(new LambdaQueryWrapper<TeachingClass>()
                        .eq(TeachingClass::getTeacherId, tid))
                .forEach(c -> mine.add(c.getId()));
        authorizationMapper.selectList(new LambdaQueryWrapper<TeacherClassAuthorization>()
                        .eq(TeacherClassAuthorization::getTeacherId, tid))
                .forEach(a -> mine.add(a.getClassId()));
        int rank = 1;
        for (Long id : classIds) {
            if (id == null || !mine.contains(id)) continue;
            TeachingClass tc = classMapper.selectById(id);
            if (tc == null) continue;
            tc.setSortOrder(rank++);
            classMapper.updateById(tc);
        }
    }

    @Override
    @Transactional
    public TeachingClassVO joinByCode(TeachingClassJoinDTO req) {
        Long uid = UserContext.requireUserId();
        String code = req.getInviteCode().trim().toUpperCase();
        TeachingClass tc = classMapper.selectOne(new LambdaQueryWrapper<TeachingClass>()
                .eq(TeachingClass::getInviteCode, code));
        if (tc == null) {
            throw new BizException(ResultCode.INVITE_CODE_INVALID);
        }
        if (tc.getStatus() == null || tc.getStatus() == 1) {
            throw new BizException(ResultCode.CLASS_DISSOLVED);
        }
        SysUser me = userMapper.selectById(uid);
        if (me == null) {
            throw new BizException(ResultCode.NOT_FOUND);
        }
        Long existing = membershipMapper.selectCount(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getStudentId, uid)
                .eq(StudentClassMembership::getClassId, tc.getId()));
        if (existing != null && existing > 0) {
            throw new BizException(ResultCode.ALREADY_IN_CLASS);
        }
        StudentClassMembership membership = new StudentClassMembership();
        membership.setStudentId(uid);
        membership.setClassId(tc.getId());
        membershipMapper.insert(membership);
        return toVO(tc);
    }

    @Override
    public List<MyClassVO> myStudentClasses() {
        Long uid = UserContext.requireUserId();
        List<StudentClassMembership> memberships = membershipMapper.selectList(
                new LambdaQueryWrapper<StudentClassMembership>()
                        .eq(StudentClassMembership::getStudentId, uid)
                        .orderByDesc(StudentClassMembership::getId));
        if (memberships.isEmpty()) return List.of();

        Map<Long, LocalDateTime> joinedByClass = new HashMap<>();
        List<Long> classIds = new ArrayList<>();
        for (StudentClassMembership m : memberships) {
            joinedByClass.put(m.getClassId(), m.getCreatedAt());
            classIds.add(m.getClassId());
        }

        List<TeachingClass> classes = classMapper.selectBatchIds(classIds)
                .stream()
                .filter(c -> c.getIsDeleted() == null || c.getIsDeleted() != 1)
                .toList();
        Map<Long, TeachingClass> classById = new HashMap<>();
        for (TeachingClass c : classes) classById.put(c.getId(), c);

        Map<Long, SysUser> teacherById = new HashMap<>();
        List<Long> teacherIds = classes.stream().map(TeachingClass::getTeacherId)
                .filter(Objects::nonNull).distinct().toList();
        if (!teacherIds.isEmpty()) {
            userMapper.selectBatchIds(teacherIds).forEach(t -> teacherById.put(t.getId(), t));
        }

        List<MyClassVO> result = new ArrayList<>();
        for (Long classId : classIds) {
            TeachingClass tc = classById.get(classId);
            if (tc == null) continue;
            SysUser teacher = teacherById.get(tc.getTeacherId());
            Long count = membershipMapper.selectCount(new LambdaQueryWrapper<StudentClassMembership>()
                    .eq(StudentClassMembership::getClassId, classId));
            result.add(MyClassVO.builder()
                    .id(tc.getId())
                    .name(tc.getName())
                    .grade(tc.getGrade())
                    .status(tc.getStatus())
                    .teacherId(tc.getTeacherId())
                    .teacherName(teacher == null ? "未知教师" : teacher.getRealName())
                    .studentCount(count)
                    .joinedAt(joinedByClass.get(classId))
                    .build());
        }
        return result;
    }

    @Override
    public StudentClassDetailVO studentClassBase(Long classId) {
        Long uid = UserContext.requireUserId();
        TeachingClass tc = requireClass(classId);
        if (tc.getStatus() == null || tc.getStatus() == 1) {
            throw new BizException(ResultCode.CLASS_DISSOLVED);
        }
        Long inClass = membershipMapper.selectCount(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getStudentId, uid)
                .eq(StudentClassMembership::getClassId, classId));
        if (inClass == null || inClass == 0) {
            throw new BizException(ResultCode.CLASS_FORBIDDEN);
        }
        SysUser teacher = tc.getTeacherId() == null ? null : userMapper.selectById(tc.getTeacherId());
        Long count = membershipMapper.selectCount(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getClassId, classId));
        StudentClassMembership myMembership = membershipMapper.selectOne(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getStudentId, uid)
                .eq(StudentClassMembership::getClassId, classId));
        List<Map<String, Object>> materials = new ArrayList<>();
        List<LessonPublish> pubs = publishMapper.selectList(new LambdaQueryWrapper<LessonPublish>()
                .eq(LessonPublish::getClassId, classId)
                .eq(LessonPublish::getStatus, 0)
                .orderByDesc(LessonPublish::getCreatedAt));
        for (LessonPublish lp : pubs) {
            LessonPlan plan = lessonPlanMapper.selectById(lp.getLessonId());
            if (plan == null) continue;
            List<LessonMaterial> mats = materialMapper.selectList(new LambdaQueryWrapper<LessonMaterial>()
                    .eq(LessonMaterial::getLessonId, plan.getId()));
            if (mats.isEmpty()) continue;
            Map<String, Object> m = new HashMap<>();
            m.put("publishId", lp.getId());
            m.put("lessonId", plan.getId());
            m.put("lessonTitle", plan.getTitle());
            m.put("department", plan.getDepartment());
            m.put("materialOnly", lp.getMaterialOnly());
            m.put("deadline", lp.getDeadline());
            m.put("assignmentId", lp.getAssignmentId());
            m.put("caseId", plan.getCaseId());
            List<Map<String, Object>> matList = new ArrayList<>();
            for (LessonMaterial mat : mats) {
                Map<String, Object> mm = new HashMap<>();
                mm.put("materialId", mat.getId());
                mm.put("title", mat.getTitle());
                mm.put("materialType", mat.getMaterialType());
                mm.put("fileUrl", mat.getFileUrl());
                mm.put("durationSec", mat.getDurationSec());
                matList.add(mm);
            }
            m.put("materials", matList);
            materials.add(m);
        }

        // 该班作业 + 我的实例状态
        List<Map<String, Object>> assignments = new ArrayList<>();
        List<AssignmentTargetClass> targets = assignmentTargetClassMapper.selectList(
                new LambdaQueryWrapper<AssignmentTargetClass>()
                        .eq(AssignmentTargetClass::getClassId, classId));
        for (AssignmentTargetClass t : targets) {
            Assignment a = assignmentMapper.selectById(t.getAssignmentId());
            if (a == null || (a.getIsDeleted() != null && a.getIsDeleted() == 1)) continue;
            AssignmentInstance mine = assignmentInstanceMapper.selectOne(new LambdaQueryWrapper<AssignmentInstance>()
                    .eq(AssignmentInstance::getAssignmentId, a.getId())
                    .eq(AssignmentInstance::getStudentId, uid));
            Map<String, Object> am = new HashMap<>();
            am.put("assignmentId", a.getId());
            am.put("title", a.getTitle());
            am.put("description", a.getDescription());
            am.put("deadline", a.getDeadline());
            am.put("status", a.getStatus());
            am.put("requireMedicalRecord", a.getRequireMedicalRecord());
            am.put("myStatus", mine == null ? 0 : mine.getStatus());
            am.put("myScore", mine == null ? null : mine.getScore());
            am.put("submitTime", mine == null ? null : mine.getSubmitTime());
            assignments.add(am);
        }

        return StudentClassDetailVO.builder()
                .classId(tc.getId())
                .name(tc.getName())
                .grade(tc.getGrade())
                .status(tc.getStatus())
                .teacherId(tc.getTeacherId())
                .teacherName(teacher == null ? "未知教师" : teacher.getRealName())
                .teacherSchool(teacher == null ? null : teacher.getSchoolName())
                .studentCount(count)
                .joinedAt(myMembership == null ? null : myMembership.getCreatedAt())
                .materials(materials)
                .assignments(assignments)
                .build();
    }

    // ---------------- helpers ----------------

    private TeachingClass requireClass(Long classId) {
        TeachingClass tc = classMapper.selectById(classId);
        if (tc == null || (tc.getIsDeleted() != null && tc.getIsDeleted() == 1)) {
            throw new BizException(ResultCode.CLASS_NOT_FOUND);
        }
        return tc;
    }

    private void requireOwner(TeachingClass tc, Long tid) {
        if (tc.getTeacherId() == null || !tc.getTeacherId().equals(tid)) {
            throw new BizException(ResultCode.CLASS_FORBIDDEN);
        }
    }

    /** 读取校验：创建教师可读，管理员预置班级（teacher_id 为空）仅凭授权可读 */
    private void requireReadable(TeachingClass tc) {
        Long tid = UserContext.requireUserId();
        if (Objects.equals(tc.getTeacherId(), tid)) {
            return;
        }
        Long authCnt = authorizationMapper.selectCount(new LambdaQueryWrapper<TeacherClassAuthorization>()
                .eq(TeacherClassAuthorization::getTeacherId, tid)
                .eq(TeacherClassAuthorization::getClassId, tc.getId()));
        if (authCnt == null || authCnt == 0) {
            throw new BizException(ResultCode.CLASS_FORBIDDEN);
        }
    }

    private TeachingClassVO toVO(TeachingClass tc) {
        Long count = membershipMapper.selectCount(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getClassId, tc.getId()));
        return TeachingClassVO.builder()
                .id(tc.getId())
                .name(tc.getName())
                .grade(tc.getGrade())
                .status(tc.getStatus())
                .teacherId(tc.getTeacherId())
                .inviteCode(tc.getInviteCode())
                .studentCount(count)
                .build();
    }

    private String uniqueInviteCode() {
        for (int attempt = 0; attempt < 50; attempt++) {
            String code = randomInvite();
            Long dup = classMapper.selectCount(new LambdaQueryWrapper<TeachingClass>()
                    .eq(TeachingClass::getInviteCode, code));
            if (dup == null || dup == 0) {
                return code;
            }
        }
        throw new BizException(ResultCode.INTERNAL_ERROR, "邀请码生成失败，请重试");
    }

    private String randomInvite() {
        String chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
        StringBuilder sb = new StringBuilder(INVITE_LEN);
        for (int i = 0; i < INVITE_LEN; i++) {
            sb.append(chars.charAt(ThreadLocalRandom.current().nextInt(chars.length())));
        }
        return sb.toString();
    }
}