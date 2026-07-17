package com.zhiyu.service;

import com.zhiyu.service.dto.TeacherAuditSubmitDTO;

/**
 * 教师个人资质服务（PRD 9.1）
 */
public interface TeacherProfileService {

    /**
     * 教师提交资质认证，audit_status: 0/3 → 1（待审核）
     */
    void submitAudit(TeacherAuditSubmitDTO dto);
}
