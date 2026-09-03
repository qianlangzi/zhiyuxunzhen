package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 当前登录用户信息
 */
@Data
@Builder
public class UserInfoVO {
    private Long id;
    private String username;
    private String realName;
    private Integer role;
    private Long classId;
    private Integer auditStatus;
    private Integer status;
    private String phone;
    private String avatar;
    private String authorizedClasses;
    private LocalDateTime lastLoginAt;
    /** 是否需要强制修改密码（批量导入学生首次登录时为 true） */
    private Boolean mustChangePassword;
}
