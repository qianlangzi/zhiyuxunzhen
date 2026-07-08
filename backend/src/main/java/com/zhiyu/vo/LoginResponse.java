package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 登录响应（PRD 9.1：返回 JWT，Payload 含 role、audit_status）
 */
@Data
@Builder
public class LoginResponse {
    private String token;
    private String refreshToken;
    private long expiresIn;
    private Long userId;
    private String username;
    private String realName;
    private Integer role;
    private Integer auditStatus;
}
