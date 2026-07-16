package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.TeacherReviewService;
import com.zhiyu.service.dto.ReviewOverrideDTO;
import com.zhiyu.vo.TeacherReviewVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 教师复核 AI 批阅服务实现（PRD 4.4.4 / 5.3 第 7 步）
 * 教师只能复核本人布置作业的实例；覆盖后实例状态置为 5（已完成）
 * 所有覆盖操作写入 medical_record_review 和 audit_log
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherReviewServiceImpl implements TeacherReviewService {

    private final MedicalRecordReviewMapper reviewMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentMapper assignmentMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    @Override
    public TeacherReviewVO getReview(Long instanceId) {
        Long teacherId = UserContext.requireUserId();
        checkInstanceBelongToTeacher(instanceId, teacherId);

        // 优先返回教师覆盖记录，其次返回 AI 批阅
        List<MedicalRecordReview> reviews = reviewMapper.selectList(
                new LambdaQueryWrapper<MedicalRecordReview>()
                        .eq(MedicalRecordReview::getInstanceId, instanceId)
                        .orderByDesc(MedicalRecordReview::getCreatedAt));
        if (reviews.isEmpty()) {
            return null;
        }
        MedicalRecordReview latest = reviews.get(0);
        return toVO(latest);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long overrideReview(Long instanceId, ReviewOverrideDTO dto) {
        Long teacherId = UserContext.requireUserId();
        AssignmentInstance inst = checkInstanceBelongToTeacher(instanceId, teacherId);

        int status = inst.getStatus() == null ? 0 : inst.getStatus();
        // 仅"待复核(4)"状态允许教师覆盖；已完成(5)如需二次修改可由管理员介入
        if (status != 4) {
            throw new BizException(ResultCode.BAD_REQUEST, "当前实例状态不支持教师复核，状态=" + status);
        }

        // 校验被覆盖的 AI 批阅记录存在且属于该实例
        MedicalRecordReview aiReview = reviewMapper.selectById(dto.getOverrideFromReviewId());
        if (aiReview == null || !instanceId.equals(aiReview.getInstanceId())) {
            throw new BizException(ResultCode.BAD_REQUEST, "被覆盖的AI批阅记录不存在或不属于该实例");
        }

        // 写入教师批阅记录
        MedicalRecordReview teacherReview = new MedicalRecordReview();
        teacherReview.setInstanceId(instanceId);
        teacherReview.setReviewerType("TEACHER");
        teacherReview.setTotalScore(dto.getTotalScore());
        teacherReview.setMistakesJson(dto.getMistakesJson());
        teacherReview.setReviewComment(dto.getReviewComment());
        teacherReview.setOverrideFromReviewId(dto.getOverrideFromReviewId());
        teacherReview.setReviewedBy(teacherId);
        reviewMapper.insert(teacherReview);

        // 实例状态 -> 已完成
        inst.setStatus(5);
        instanceMapper.updateById(inst);

        // 审计日志
        Map<String, Object> before = new HashMap<>();
        before.put("status", status);
        before.put("aiReviewId", dto.getOverrideFromReviewId());
        Map<String, Object> after = new HashMap<>();
        after.put("status", 5);
        after.put("teacherReviewId", teacherReview.getId());
        after.put("totalScore", dto.getTotalScore());
        auditLogService.record(
                "teacher_review_override",
                "medical_record_review",
                teacherReview.getId(),
                toJson(before),
                toJson(after));

        log.info("教师{}覆盖实例{}批阅结果，teacherReviewId={} score={}",
                teacherId, instanceId, teacherReview.getId(), dto.getTotalScore());
        return teacherReview.getId();
    }

    /**
     * 校验实例存在、属于当前教师布置的作业
     */
    private AssignmentInstance checkInstanceBelongToTeacher(Long instanceId, Long teacherId) {
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
        }
        Assignment a = assignmentMapper.selectById(inst.getAssignmentId());
        if (a == null) {
            throw new BizException(ResultCode.ASSIGNMENT_NOT_FOUND);
        }
        if (!teacherId.equals(a.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能复核本人布置作业的实例");
        }
        return inst;
    }

    private TeacherReviewVO toVO(MedicalRecordReview r) {
        return TeacherReviewVO.builder()
                .reviewId(r.getId())
                .instanceId(r.getInstanceId())
                .reviewerType(r.getReviewerType())
                .totalScore(r.getTotalScore())
                .mistakesJson(r.getMistakesJson())
                .reviewComment(r.getReviewComment())
                .overrideFromReviewId(r.getOverrideFromReviewId())
                .reviewedBy(r.getReviewedBy())
                .createdAt(r.getCreatedAt())
                .updatedAt(r.getUpdatedAt())
                .build();
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            log.warn("JSON序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
