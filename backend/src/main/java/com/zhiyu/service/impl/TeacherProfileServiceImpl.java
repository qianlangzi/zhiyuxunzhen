package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.AuditLog;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.AuditLogMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.TeacherProfileService;
import com.zhiyu.service.dto.TeacherAuditSubmitDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.Map;

/**
 * 教师个人资质服务实现（PRD 9.1）
 * 教师提交资质认证：audit_status 0(未提交)/3(驳回) → 1(待审核)
 * 资质材料 JSON 写入 audit_log（action=teacher_audit_submit），管理员审核时可联表查询
 * 这样避免修改 sys_user 表结构，同时保留完整的资质提交历史
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherProfileServiceImpl implements TeacherProfileService {

    private final SysUserMapper userMapper;
    private final AuditLogMapper auditLogMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void submitAudit(TeacherAuditSubmitDTO dto) {
        Long teacherId = UserContext.requireUserId();
        SysUser user = userMapper.selectById(teacherId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() == null || user.getRole() != 1) {
            throw new BizException(ResultCode.FORBIDDEN, "仅教师角色可提交资质认证");
        }

        int current = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
        // 仅"未提交(0)"或"驳回(3)"状态允许提交；"待审核(1)"和"通过(2)"不允许重复提交
        if (current == 1) {
            throw new BizException(ResultCode.TEACHER_AUDIT_PENDING);
        }
        if (current == 2) {
            throw new BizException(ResultCode.BAD_REQUEST, "资质已审核通过，无需重复提交");
        }

        // 更新审核状态
        Map<String, Object> before = new HashMap<>();
        before.put("auditStatus", current);

        // P0-4 修复：使用窄字段 UpdateWrapper 只更新审核相关列。
        // updateById(user) 会写入完整实体快照，并发场景下可能把另一个事务已递增的
        // credential_version 或修改的 role/status/passwordHash 写回旧值，导致撤销被回滚。
        //
        // P1-1 修复：CAS 条件增加 .eq("audit_status", current)，仅当前状态未变才允许提交。
        // 防止迟到提交覆盖较新的审核结果（教师提交后管理员已审批，但迟到的提交请求
        // 在审批之后执行，把已通过/驳回的状态又改成待审核）。
        //
        // H3 修复：CAS 增加 .eq("credential_version", user.getCredentialVersion()) 消除 ABA。
        String trimmedDept = dto.getDepartment() == null ? null : dto.getDepartment().trim();
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", teacherId)
                        .eq("audit_status", current)
                        .eq("credential_version", user.getCredentialVersion())
                        .set("audit_status", 1)
                        .set("teacher_certificate_no", dto.getCertificateNo().trim())
                        .set("department", trimmedDept));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "审核状态已变更，请刷新后重试");
        }

        // 资质材料 JSON（管理员审核时查询）
        Map<String, Object> material = new HashMap<>();
        material.put("auditStatus", 1);
        material.put("certificateNo", dto.getCertificateNo());
        material.put("certificateUrl", dto.getCertificateUrl());
        material.put("department", dto.getDepartment());
        material.put("remark", dto.getRemark());
        material.put("submitAt", System.currentTimeMillis());

        // 写审计日志（携带资质材料，管理员可查询）
        auditLogService.record(
                "teacher_audit_submit",
                "user",
                teacherId,
                toJson(before),
                toJson(material));

        log.info("教师{}提交资质认证，certificateNo={}", teacherId, dto.getCertificateNo());
    }

    /**
     * 查询某教师最近一次资质提交材料（供管理员审核时调用）
     */
    public String getLatestAuditMaterial(Long teacherId) {
        AuditLog auditLog = auditLogMapper.selectOne(
                new LambdaQueryWrapper<AuditLog>()
                        .eq(AuditLog::getAction, "teacher_audit_submit")
                        .eq(AuditLog::getTargetType, "user")
                        .eq(AuditLog::getTargetId, teacherId)
                        .orderByDesc(AuditLog::getCreatedAt)
                        .last("LIMIT 1"));
        return auditLog == null ? null : auditLog.getAfterJson();
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            return null;
        }
    }
}
