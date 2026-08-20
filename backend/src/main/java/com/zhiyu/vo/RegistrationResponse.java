package com.zhiyu.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class RegistrationResponse {
    private Long userId;
    private String username;
    private String realName;
    private Integer role;
    private Integer auditStatus;
    private String message;

    /**
     * 学生注册成功即发放 token，前端可直接进入主页（免二次登录）。
     * 教师因需人工审核，不发放 token。
     */
    private String token;
}