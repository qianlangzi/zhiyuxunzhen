package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

/**
 * 系统用户表（PRD 8.1）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("sys_user")
public class SysUser extends BaseEntity {

    private String username;

    private String passwordHash;

    private String realName;

    /** 0学生 1教师 2教学秘书 3教研室主任 4管理员 5运维 */
    private Integer role;

    /** 学生所属班级 */
    private Long classId;

    /** 教师认证状态：0未提交 1待审核 2通过 3驳回 */
    private Integer auditStatus;

    /** 0正常 1冻结 */
    private Integer status;

    private String phone;

    private String idCard;

    private String teacherCertificateNo;

    private String department;

    private String avatar;

    /** 教师授权班级（JSON 数组，如 [1,2,3]） */
    private String authorizedClasses;

    private LocalDateTime lastLoginAt;

    @TableLogic
    @TableField(value = "is_deleted")
    private Integer isDeleted;
}
