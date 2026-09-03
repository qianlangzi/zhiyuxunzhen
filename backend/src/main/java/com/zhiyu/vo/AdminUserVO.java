package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 管理端-用户列表项（人数管理）
 * 覆盖全部角色：学生/教师/教学秘书/教研室主任/管理员/运维/审核员
 */
@Data
@Builder
public class AdminUserVO {

    private Long id;
    private String username;
    private String realName;

    /** 0学生 1教师 2教学秘书 3教研室主任 4管理员 5运维 6审核员 */
    private Integer role;

    /** 角色中文名，前端直接展示，避免各自维护映射 */
    private String roleName;

    private Long classId;

    /** 学生班级名称（如：临床2101班） */
    private String className;

    private String schoolName;
    private String grade;
    private String department;
    private String phone;

    /** 教师认证状态：0未提交 1待审核 2通过 3驳回；非教师为 null */
    private Integer auditStatus;

    /** 0正常 1冻结 */
    private Integer status;

    /** 是否强制修改密码（批量导入学生首次登录为 true） */
    private Boolean mustChangePassword;

    private LocalDateTime lastLoginAt;
    private LocalDateTime createdAt;
}
