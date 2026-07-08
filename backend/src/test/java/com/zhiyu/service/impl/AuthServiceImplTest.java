package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.vo.LoginResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * 认证服务 — 单元测试（纯 Mockito）
 */
@DisplayName("认证服务 AuthServiceImpl")
@ExtendWith(MockitoExtension.class)
class AuthServiceImplTest {

    @Mock
    private SysUserMapper userMapper;

    @Mock
    private JwtUtils jwtUtils;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private AuthServiceImpl authService;

    /** 构造一个正常的学生用户 */
    private SysUser studentUser() {
        SysUser u = new SysUser();
        u.setId(1L);
        u.setUsername("student01");
        u.setPasswordHash("$2a$10$hashedpassword");
        u.setRealName("张三");
        u.setRole(0);
        u.setStatus(0);
        u.setAuditStatus(0);
        return u;
    }

    @Test
    @DisplayName("login 成功（账号密码正确、status=0）→ 返回 LoginResponse 含 token")
    void should_return_login_response_when_credentials_correct() {
        SysUser user = studentUser();
        when(userMapper.selectOne(any())).thenReturn(user);
        when(passwordEncoder.matches("123456", user.getPasswordHash())).thenReturn(true);
        when(userMapper.updateById(any())).thenReturn(1);
        when(jwtUtils.issueToken(1L, "student01", 0, 0)).thenReturn("access-token");
        when(jwtUtils.issueRefreshToken(1L)).thenReturn("refresh-token");
        when(jwtUtils.getAccessExpireMs()).thenReturn(3600_000L);

        LoginRequest req = new LoginRequest();
        req.setUsername("student01");
        req.setPassword("123456");

        LoginResponse resp = authService.login(req);

        assertThat(resp).isNotNull();
        assertThat(resp.getToken()).isEqualTo("access-token");
        assertThat(resp.getRefreshToken()).isEqualTo("refresh-token");
        assertThat(resp.getUserId()).isEqualTo(1L);
        assertThat(resp.getUsername()).isEqualTo("student01");
        assertThat(resp.getRole()).isEqualTo(0);
        assertThat(resp.getAuditStatus()).isEqualTo(0);
        assertThat(resp.getExpiresIn()).isEqualTo(3600L);

        verify(userMapper).updateById(any());
    }

    @Test
    @DisplayName("login 账号不存在 → BizException(USERNAME_OR_PASSWORD_ERROR)")
    void should_throw_when_user_not_found() {
        when(userMapper.selectOne(any())).thenReturn(null);

        LoginRequest req = new LoginRequest();
        req.setUsername("nobody");
        req.setPassword("123456");

        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.USERNAME_OR_PASSWORD_ERROR.getCode()));

        verify(passwordEncoder, never()).matches(anyString(), anyString());
    }

    @Test
    @DisplayName("login 密码错误 → BizException(USERNAME_OR_PASSWORD_ERROR)")
    void should_throw_when_password_wrong() {
        SysUser user = studentUser();
        when(userMapper.selectOne(any())).thenReturn(user);
        when(passwordEncoder.matches("wrong", user.getPasswordHash())).thenReturn(false);

        LoginRequest req = new LoginRequest();
        req.setUsername("student01");
        req.setPassword("wrong");

        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.USERNAME_OR_PASSWORD_ERROR.getCode()));

        verify(userMapper, never()).updateById(any());
    }

    @Test
    @DisplayName("login 账号冻结（status=1）→ BizException(ACCOUNT_FROZEN)")
    void should_throw_when_account_frozen() {
        SysUser user = studentUser();
        user.setStatus(1); // 冻结
        when(userMapper.selectOne(any())).thenReturn(user);
        when(passwordEncoder.matches("123456", user.getPasswordHash())).thenReturn(true);

        LoginRequest req = new LoginRequest();
        req.setUsername("student01");
        req.setPassword("123456");

        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.ACCOUNT_FROZEN.getCode()));
    }

    @Test
    @DisplayName("login 教师未审核（role=1, audit_status=0）→ 实际代码允许登录，返回 token（auditStatus=0）")
    void should_allow_login_for_unaudited_teacher() {
        // 注意：实际 AuthServiceImpl.login 不检查 audit_status，
        // 教师未审核仍可登录，token 中携带 auditStatus=0，
        // 资质校验由 PermissionInterceptor 在写接口时拦截。
        SysUser user = new SysUser();
        user.setId(10L);
        user.setUsername("teacher01");
        user.setPasswordHash("$2a$10$hash");
        user.setRealName("李老师");
        user.setRole(1);
        user.setStatus(0);
        user.setAuditStatus(0);

        when(userMapper.selectOne(any())).thenReturn(user);
        when(passwordEncoder.matches("123456", user.getPasswordHash())).thenReturn(true);
        when(userMapper.updateById(any())).thenReturn(1);
        when(jwtUtils.issueToken(10L, "teacher01", 1, 0)).thenReturn("teacher-token");
        when(jwtUtils.issueRefreshToken(10L)).thenReturn("teacher-refresh");
        when(jwtUtils.getAccessExpireMs()).thenReturn(3600_000L);

        LoginRequest req = new LoginRequest();
        req.setUsername("teacher01");
        req.setPassword("123456");

        LoginResponse resp = authService.login(req);

        assertThat(resp).isNotNull();
        assertThat(resp.getToken()).isEqualTo("teacher-token");
        assertThat(resp.getRole()).isEqualTo(1);
        assertThat(resp.getAuditStatus()).isEqualTo(0);
    }
}
