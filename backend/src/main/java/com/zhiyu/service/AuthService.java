package com.zhiyu.service;

import com.zhiyu.entity.SysUser;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.UserInfoVO;

/**
 * 认证服务（PRD 9.1）
 */
public interface AuthService {

    /**
     * 登录：校验密码并签发 JWT（含 role、audit_status）
     */
    LoginResponse login(LoginRequest req);

    /**
     * 刷新 token：用 refresh token 换新的 access token
     */
    LoginResponse refresh(String refreshToken);

    /**
     * 获取当前用户信息
     */
    UserInfoVO currentUser(Long userId);

    /**
     * 更新最后登录时间
     */
    void updateLastLogin(Long userId);
}
