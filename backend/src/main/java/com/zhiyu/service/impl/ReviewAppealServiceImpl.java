package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentItemProgress;
import com.zhiyu.entity.AssignmentTargetClass;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.ReviewAppeal;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.AssignmentTargetClassMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.ReviewAppealMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.ReviewAppealService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
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
 * 批阅申诉服务实现（PRD 4.4.5）
 * 学生可对已出批阅结果的大病历/主观题发起申诉，教师处理后回复并可选覆盖得分。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReviewAppealServiceImpl implements ReviewAppealService {

    private final ReviewAppealMapper appealMapper;
    private final MedicalRecordReviewMapper reviewMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentMapper assignmentMapper;
    private final AssignmentItemProgressMapper progressMapper;
    private final AssignmentTargetClassMapper targetClassMapper;
    private final TeachingClassMapper classMapper;
    private final SysUserMapper userMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long create(Long instanceId, String reason) {
        Long studentId = UserContext.requireUserId();
        if (isBlank(reason)) {
            throw new BizException(ResultCode.BAD_REQUEST, "申诉理由不能为空");
        }
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
        }
        if (!studentId.equals(inst.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能对本人作业发起申诉");
        }
        MedicalRecordReview latest = latestReviewByInstance(instanceId);
        if (latest == null) {
            throw new BizException(ResultCode.NOT_FOUND, "尚无批阅结果，暂不能发起申诉");
        }
        // 同一批阅仍处于待处理状态时禁止重复申诉
        Long duplicated = appealMapper.selectCount(new LambdaQueryWrapper<ReviewAppeal>()
                .eq(ReviewAppeal::getInstanceId, instanceId)
                .eq(ReviewAppeal::getStudentId, studentId)
                .eq(ReviewAppeal::getStatus, ReviewAppeal.STATUS_PENDING));
        if (duplicated != null && duplicated > 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "已有待处理的申诉，请勿重复提交");
        }

        ReviewAppeal appeal = new ReviewAppeal();
        appeal.setInstanceId(instanceId);
        appeal.setReviewId(latest.getId());
        appeal.setStudentId(studentId);
        appeal.setReason(reason);
        appeal.setStatus(ReviewAppeal.STATUS_PENDING);
        appealMapper.insert(appeal);

        auditLogService.record(
                "student_appeal_create", "review_appeal", appeal.getId(),
                null, toJson(Map.of("instanceId", instanceId, "reviewId", latest.getId())));
        log.info("学生{}对实例{}发起批阅申诉，appealId={}", studentId, instanceId, appeal.getId());
        return appeal.getId();
    }

    @Override
    public List<Map<String, Object>> myAppeals() {
        Long studentId = UserContext.requireUserId();
        List<ReviewAppeal> appeals = appealMapper.selectList(
                new LambdaQueryWrapper<ReviewAppeal>()
                        .eq(ReviewAppeal::getStudentId, studentId)
                        .orderByDesc(ReviewAppeal::getCreatedAt));
        if (appeals.isEmpty()) {
            return List.of();
        }
        Set<Long> instIds = appeals.stream().map(ReviewAppeal::getInstanceId)
                .filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, AssignmentInstance> instMap = instIds.isEmpty() ? Map.of()
                : instanceMapper.selectBatchIds(instIds).stream()
                        .collect(Collectors.toMap(AssignmentInstance::getId, Function.identity()));
        Set<Long> assignmentIds = instMap.values().stream().map(AssignmentInstance::getAssignmentId)
                .filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, Assignment> assignmentMap = assignmentIds.isEmpty() ? Map.of()
                : assignmentMapper.selectBatchIds(assignmentIds).stream()
                        .collect(Collectors.toMap(Assignment::getId, Function.identity()));
        Set<Long> reviewIds = appeals.stream().map(ReviewAppeal::getReviewId)
                .filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, MedicalRecordReview> reviewMap = reviewIds.isEmpty() ? Map.of()
                : reviewMapper.selectBatchIds(reviewIds).stream()
                        .collect(Collectors.toMap(MedicalRecordReview::getId, Function.identity()));

        List<Map<String, Object>> result = new ArrayList<>();
        for (ReviewAppeal a : appeals) {
            AssignmentInstance inst = instMap.get(a.getInstanceId());
            Assignment assignment = inst == null ? null : assignmentMap.get(inst.getAssignmentId());
            MedicalRecordReview review = reviewMap.get(a.getReviewId());
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", a.getId());
            m.put("instanceId", a.getInstanceId());
            m.put("assignmentTitle", assignment == null ? "作业" : assignment.getTitle());
            m.put("reason", a.getReason());
            m.put("status", a.getStatus());
            m.put("statusText", statusText(a.getStatus()));
            m.put("reply", a.getReply());
            m.put("totalScore", review == null ? null : review.getTotalScore());
            m.put("createdAt", a.getCreatedAt());
            m.put("reviewedAt", a.getUpdatedAt());
            m.put("reviewedBy", a.getReviewedBy());
            result.add(m);
        }
        return result;
    }

    @Override
    public List<Map<String, Object>> teacherAppeals(Integer status) {
        Long teacherId = UserContext.requireUserId();
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>().eq(Assignment::getTeacherId, teacherId));
        if (assignments.isEmpty()) {
            return List.of();
        }
        List<Long> assignmentIds = assignments.stream().map(Assignment::getId).toList();
        Long count = instanceMapper.selectCount(new LambdaQueryWrapper<AssignmentInstance>()
                .in(AssignmentInstance::getAssignmentId, assignmentIds));
        List<AssignmentInstance> instances = count != null && count > 0
                ? instanceMapper.selectList(new LambdaQueryWrapper<AssignmentInstance>()
                        .in(AssignmentInstance::getAssignmentId, assignmentIds))
                : List.of();
        if (instances.isEmpty()) {
            return List.of();
        }
        List<Long> instIds = instances.stream().map(AssignmentInstance::getId).toList();
        LambdaQueryWrapper<ReviewAppeal> wrapper = new LambdaQueryWrapper<ReviewAppeal>()
                .in(ReviewAppeal::getInstanceId, instIds)
                .orderByDesc(ReviewAppeal::getCreatedAt);
        if (status != null && (status == ReviewAppeal.STATUS_PENDING
                || status == ReviewAppeal.STATUS_HANDLED
                || status == ReviewAppeal.STATUS_REJECTED)) {
            wrapper.eq(ReviewAppeal::getStatus, status);
        }
        List<ReviewAppeal> appeals = appealMapper.selectList(wrapper);
        if (appeals.isEmpty()) {
            return List.of();
        }

        Map<Long, AssignmentInstance> instMap = instanceMapper.selectBatchIds(instIds).stream()
                .collect(Collectors.toMap(AssignmentInstance::getId, Function.identity()));
        Set<Long> queryAssignmentIds = instMap.values().stream()
                .map(AssignmentInstance::getAssignmentId).collect(Collectors.toSet());
        Map<Long, Assignment> assignmentMap = queryAssignmentIds.isEmpty() ? Map.of()
                : assignmentMapper.selectBatchIds(queryAssignmentIds).stream()
                        .collect(Collectors.toMap(Assignment::getId, Function.identity()));
        Set<Long> studentIds = instMap.values().stream().map(AssignmentInstance::getStudentId)
                .filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, String> studentNames = studentIds.isEmpty() ? Map.of()
                : userMapper.selectBatchIds(studentIds).stream()
                        .collect(Collectors.toMap(SysUser::getId, u -> Objects.toString(u.getRealName(), "")));

        // 作业 -> 首个目标班级名（用于展示）
        Map<Long, String> classNameById = new HashMap<>();
        List<AssignmentTargetClass> targets = queryAssignmentIds.isEmpty() ? List.of()
                : targetClassMapper.selectList(new LambdaQueryWrapper<AssignmentTargetClass>()
                        .in(AssignmentTargetClass::getAssignmentId, queryAssignmentIds));
        Set<Long> classIds = targets.stream().map(AssignmentTargetClass::getClassId)
                .filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, Long> firstByAssignment = new HashMap<>();
        targets.forEach(t -> firstByAssignment.putIfAbsent(t.getAssignmentId(), t.getClassId()));
        if (!classIds.isEmpty()) {
            classMapper.selectBatchIds(classIds)
                    .forEach(c -> classNameById.put(c.getId(), c.getName()));
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (ReviewAppeal a : appeals) {
            AssignmentInstance inst = instMap.get(a.getInstanceId());
            Assignment assignment = inst == null ? null : assignmentMap.get(inst.getAssignmentId());
            Long classId = assignment == null ? null : firstByAssignment.get(assignment.getId());
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", a.getId());
            m.put("instanceId", a.getInstanceId());
            m.put("studentId", a.getStudentId());
            m.put("studentName", inst == null ? "" : studentNames.getOrDefault(inst.getStudentId(), ""));
            m.put("assignmentTitle", assignment == null ? "作业" : assignment.getTitle());
            m.put("className", classId == null ? "" : classNameById.getOrDefault(classId, ""));
            m.put("reason", a.getReason());
            m.put("status", a.getStatus());
            m.put("statusText", statusText(a.getStatus()));
            m.put("reply", a.getReply());
            m.put("createdAt", a.getCreatedAt());
            result.add(m);
        }
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void handle(Long appealId, Integer status, String reply, BigDecimal newScore) {
        Long teacherId = UserContext.requireUserId();
        if (status == null || (status != ReviewAppeal.STATUS_HANDLED && status != ReviewAppeal.STATUS_REJECTED)) {
            throw new BizException(ResultCode.BAD_REQUEST, "处理状态只能是已处理或已驳回");
        }
        ReviewAppeal appeal = appealMapper.selectById(appealId);
        if (appeal == null) {
            throw new BizException(ResultCode.NOT_FOUND, "申诉不存在");
        }
        if (appeal.getStatus() != ReviewAppeal.STATUS_PENDING) {
            throw new BizException(ResultCode.BAD_REQUEST, "该申诉已处理，不可重复操作");
        }
        AssignmentInstance inst = instanceMapper.selectById(appeal.getInstanceId());
        Assignment assignment = inst == null ? null : assignmentMapper.selectById(inst.getAssignmentId());
        if (assignment == null || !teacherId.equals(assignment.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能处理本人布置作业的申诉");
        }

        String before = toJson(Map.of("status", appeal.getStatus(), "score", null));
        appeal.setStatus(status);
        appeal.setReply(reply);
        appeal.setReviewedBy(teacherId);
        appealMapper.updateById(appeal);

        // 可选：教师改分覆盖该批阅得分，并同步实例/任务项得分
        BigDecimal oldScore = null;
        if (newScore != null) {
            MedicalRecordReview review = appeal.getReviewId() == null
                    ? null : reviewMapper.selectById(appeal.getReviewId());
            if (review != null) {
                oldScore = review.getTotalScore();
                review.setTotalScore(newScore);
                reviewMapper.updateById(review);
            }
            if (inst != null) {
                inst.setScore(newScore);
                instanceMapper.updateById(inst);
            }
            if (review != null && review.getAssignmentItemProgressId() != null) {
                AssignmentItemProgress p = progressMapper.selectById(review.getAssignmentItemProgressId());
                if (p != null) {
                    p.setScore(newScore);
                    progressMapper.updateById(p);
                }
            }
        }

        auditLogService.record(
                "teacher_appeal_handle", "review_appeal", appeal.getId(),
                before,
                toJson(Map.of("status", status, "reply", reply,
                        "oldScore", oldScore, "newScore", newScore)));
        log.info("教师{}处理申诉{}：status={} reply={} newScore={}",
                teacherId, appealId, status, reply, newScore);
    }

    private MedicalRecordReview latestReviewByInstance(Long instanceId) {
        List<MedicalRecordReview> reviews = reviewMapper.selectList(
                new LambdaQueryWrapper<MedicalRecordReview>()
                        .eq(MedicalRecordReview::getInstanceId, instanceId)
                        .orderByDesc(MedicalRecordReview::getCreatedAt));
        return reviews.isEmpty() ? null : reviews.get(0);
    }

    private String statusText(Integer status) {
        return switch (status == null ? ReviewAppeal.STATUS_PENDING : status) {
            case ReviewAppeal.STATUS_PENDING -> "待处理";
            case ReviewAppeal.STATUS_HANDLED -> "已处理";
            case ReviewAppeal.STATUS_REJECTED -> "已驳回";
            default -> "未知";
        };
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            return null;
        }
    }
}