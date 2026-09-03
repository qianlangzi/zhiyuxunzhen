package com.zhiyu.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
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

    private static final ObjectMapper JSON_MAPPER = new ObjectMapper();

    @Override
    public void record(String action, String targetType, Long targetId, String beforeJson, String afterJson) {
        // P1-5 修复：移除 try-catch，让 DB 写入异常传播到 @Transactional 调用方。
        // 旧实现吞掉异常 → 业务操作成功但审计日志丢失 → 安全审计与业务状态不一致。
        // 现在：审计日志写入失败 → 异常传播 → @Transactional 回滚 → 业务操作也回滚 → 一致。
        // getClientIp() 内部已有 try-catch，不会抛异常。
        AuditLog auditLog = new AuditLog();
        auditLog.setAction(action);
        auditLog.setTargetType(targetType);
        auditLog.setTargetId(targetId);
        auditLog.setBeforeJson(toValidJson(beforeJson));
        auditLog.setAfterJson(toValidJson(afterJson));
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
    }

    /**
     * before_json / after_json 列为 MySQL JSON 类型：非法 JSON 会导致整个业务事务回滚。
     * 历史调用方存在传普通字符串（如 "sp/v1"）的情况，这里统一兜底：
     * 已是合法 JSON → 原样写入；否则转成 JSON 字符串标量（带引号转义），保证审计列永远可写。
     */
    private String toValidJson(String raw) {
        if (raw == null || raw.isBlank()) {
            return raw;
        }
        try {
            JSON_MAPPER.readTree(raw);
            return raw;
        } catch (Exception e) {
            try {
                return JSON_MAPPER.writeValueAsString(raw);
            } catch (Exception impossible) {
                return null;
            }
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
