package com.zhiyu.service;

import com.zhiyu.entity.SysUser;
import com.zhiyu.service.dto.ChangePasswordRequest;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.service.dto.ProfileUpdateDTO;
import com.zhiyu.service.dto.RegisterRequest;
import com.zhiyu.service.dto.SmsLoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.RegistrationResponse;
import com.zhiyu.vo.UserInfoVO;

/**
 * 认证服务（PRD 9.1）
 */
public interface AuthService {

    /**
     * 登录：校验密码并签发 JWT（含 role、audit_status）
     */
    LoginResponse login(LoginRequest req);

    RegistrationResponse register(RegisterRequest req);

    /** 手机号和一次性验证码登录。 */
    LoginResponse smsLogin(SmsLoginRequest req);

    /**
     * 刷新 token：用 refresh token 换新的 access token
     */
    LoginResponse refresh(String refreshToken);

    /**
     * 获取当前用户信息
     */
    UserInfoVO currentUser(Long userId);

    /**
     * 更新当前用户个人资料
     */
    UserInfoVO updateProfile(Long userId, ProfileUpdateDTO dto);

    /**
     * 更新最后登录时间
     */
    void updateLastLogin(Long userId);

    /**
     * 修改密码：校验原密码 → CAS 更新密码哈希 + 递增凭证版本 + 清除强制改密标志 → 签发新 token。
     * 用于批量导入学生首次登录强制改密，以及用户主动改密。
     *
     * @return 包含新 access/refresh token 的 LoginResponse（携带递增后的 credentialVersion），
     *         客户端必须用新 token 替换旧 token，旧 token 因版本不匹配被后端拒绝
     */
    LoginResponse changePassword(Long userId, ChangePasswordRequest req);
}
