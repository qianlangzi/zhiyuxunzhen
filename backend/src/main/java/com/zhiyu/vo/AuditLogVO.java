package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 审计日志查询结果（PRD 4.17）
 */
@Data
@Builder
public class AuditLogVO {

    private Long id;

    private Long operatorId;

    private String operatorName;

    private Integer operatorRole;

    private String action;

    private String targetType;

    private Long targetId;

    private String beforeJson;

    private String afterJson;

    private String ipAddress;

    private LocalDateTime createdAt;
}
