package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 教师资质审核列表项（PRD 4.14）
 */
@Data
@Builder
public class TeacherAuditVO {

    private Long userId;

    private String username;

    private String realName;

    /** 脱敏手机号 */
    private String phone;

    /** 教师认证状态：0未提交 1待审核 2通过 3驳回 */
    private Integer auditStatus;

    private LocalDateTime createdAt;
}
