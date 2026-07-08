package com.zhiyu.service.impl;

import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.AuditLog;
import com.zhiyu.mapper.AuditLogMapper;
import com.zhiyu.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.LocalDateTime;

/**
 * 审计日志服务实现（PRD 8.12 / 10.3）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditLogServiceImpl implements AuditLogService {

    private final AuditLogMapper auditLogMapper;

    @Override
    public void record(String action, String targetType, Long targetId, String beforeJson, String afterJson) {
        try {
            AuditLog auditLog = new AuditLog();
            auditLog.setAction(action);
            auditLog.setTargetType(targetType);
            auditLog.setTargetId(targetId);
            auditLog.setBeforeJson(beforeJson);
            auditLog.setAfterJson(afterJson);
            auditLog.setIpAddress(getClientIp());
            auditLog.setCreatedAt(LocalDateTime.now());

            // 从用户上下文取操作人信息（内部回调无用户上下文时记为系统操作）
            UserContext.LoginUser user = UserContext.get();
            if (user != null) {
                auditLog.setOperatorId(user.getUserId());
                auditLog.setOperatorRole(user.getRole());
            } else {
                auditLog.setOperatorId(0L);
                auditLog.setOperatorRole(null);
            }

            auditLogMapper.insert(auditLog);
        } catch (Exception e) {
            // 审计日志写入失败不应影响主业务流程
            log.error("审计日志写入失败: action={}, targetType={}, targetId={}", action, targetType, targetId, e);
        }
    }

    /**
     * 从当前请求上下文获取客户端IP
     */
    private String getClientIp() {
        try {
            ServletRequestAttributes attrs = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
            if (attrs == null) {
                return null;
            }
            HttpServletRequest req = attrs.getRequest();
            String ip = req.getHeader("X-Forwarded-For");
            if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
                ip = req.getHeader("X-Real-IP");
            }
            if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
                ip = req.getRemoteAddr();
            }
            // 多级代理时取第一个
            if (ip != null && ip.contains(",")) {
                ip = ip.split(",")[0].trim();
            }
            return ip;
        } catch (Exception e) {
            return null;
        }
    }
}
