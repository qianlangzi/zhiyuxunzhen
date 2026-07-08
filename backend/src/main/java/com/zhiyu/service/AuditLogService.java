package com.zhiyu.service;

/**
 * 审计日志服务（PRD 8.12 / 10.3）
 * 封装审计日志写入，自动从 UserContext 取操作人、从 RequestContext 取 IP
 */
public interface AuditLogService {

    /**
     * 记录审计日志
     *
     * @param action      操作动作（如 teacher_audit_approve / case_audit_reject）
     * @param targetType  操作对象类型（如 user / sp_case_config / sys_config）
     * @param targetId    操作对象ID，可为 null
     * @param beforeJson  变更前数据 JSON，可为 null
     * @param afterJson   变更后数据 JSON，可为 null
     */
    void record(String action, String targetType, Long targetId, String beforeJson, String afterJson);
}
