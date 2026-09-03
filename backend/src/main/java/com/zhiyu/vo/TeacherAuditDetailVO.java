package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 教师资质审核详情（PRD 4.14 扩展：查看详情）
 * 供审核人/管理员查看教师的完整资质信息。
 */
@Data
@Builder
public class TeacherAuditDetailVO {

    private Long userId;

    private String username;

    private String realName;

    /** 完整手机号（列表页脱敏，详情页供审核人联系使用） */
    private String phone;

    private String idCard;

    private String department;

    private String schoolName;

    /** 学生年级（教师端注册时填写） */
    private String grade;

    private String className;

    private String teacherCertificateNo;

    /** 资质证书图片路径 */
    private String teacherCertificateImage;

    private String avatar;

    /** 0正常 1冻结 */
    private Integer status;

    /** 0未提交 1待审核 2通过 3驳回 */
    private Integer auditStatus;

    private LocalDateTime createdAt;

    private LocalDateTime lastLoginAt;
}