package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 审计日志表（PRD 8.12）
 * 不含逻辑删除字段，日志只增不改不删
 */
@Data
@TableName("audit_log")
public class AuditLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long operatorId;

    private Integer operatorRole;

    private String action;

    private String targetType;

    private Long targetId;

    private String beforeJson;

    private String afterJson;

    private String ipAddress;

    private LocalDateTime createdAt;
}
