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

    /**
     * 查询某教师最近一次资质提交材料（供管理员审核时调用）
     *
     * @param teacherId 教师用户 ID
     * @return 资质材料 JSON，未提交过返回 null
     */
    String getLatestAuditMaterial(Long teacherId);
}
