package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.SmsCodeService;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.service.dto.RegisterRequest;
import com.zhiyu.service.dto.SmsLoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.RegistrationResponse;
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

    @Mock
    private SmsCodeService smsCodeService;

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
    @DisplayName("register 学生成功 -> 验证短信、BCrypt 加密并创建普通账号")
    void should_register_student() {
        when(userMapper.selectCount(any())).thenReturn(0L);
        when(passwordEncoder.encode("study2026")).thenReturn("encoded-password");
        when(userMapper.insert(any(SysUser.class))).thenAnswer(invocation -> {
            SysUser user = invocation.getArgument(0);
            user.setId(21L);
            return 1;
        });

        RegisterRequest req = registration(0);
        RegistrationResponse response = authService.register(req);

        verify(smsCodeService).verifyAndConsume("18500000003", "123456");
        verify(userMapper).insert(argThat(user ->
                user.getRole() == 0
                        && user.getAuditStatus() == 0
                        && "encoded-password".equals(user.getPasswordHash())
                        && user.getTeacherCertificateNo() == null));
        assertThat(response.getUserId()).isEqualTo(21L);
        assertThat(response.getAuditStatus()).isZero();
    }

    @Test
    @DisplayName("register 教师成功 -> 保存资质并进入待审核")
    void should_register_teacher_as_pending() {
        when(userMapper.selectCount(any())).thenReturn(0L);
        when(passwordEncoder.encode("study2026")).thenReturn("encoded-password");
        when(userMapper.insert(any(SysUser.class))).thenAnswer(invocation -> {
            SysUser user = invocation.getArgument(0);
            user.setId(22L);
            return 1;
        });

        RegisterRequest req = registration(1);
        req.setCertificateNo("CERT-2026-001");
        req.setDepartment("心内科");
        req.setTeacherCertificateImage("/uploads/certificates/cert_test.png");
        RegistrationResponse response = authService.register(req);

        verify(userMapper).insert(argThat(user ->
                user.getRole() == 1
                        && user.getAuditStatus() == 1
                        && "CERT-2026-001".equals(user.getTeacherCertificateNo())
                        && "心内科".equals(user.getDepartment())));
        assertThat(response.getAuditStatus()).isEqualTo(1);
        assertThat(response.getMessage()).contains("审核");
    }

    @Test
    @DisplayName("register 重复账号 -> 拒绝且不消耗验证码")
    void should_reject_duplicate_username_before_consuming_code() {
        when(userMapper.selectCount(any())).thenReturn(1L);

        assertThatThrownBy(() -> authService.register(registration(0)))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.USERNAME_EXISTS.getCode()));

        verify(smsCodeService, never()).verifyAndConsume(anyString(), anyString());
        verify(userMapper, never()).insert(any());
    }

    @Test
    @DisplayName("register 教师缺少资质 -> 拒绝且不消耗验证码")
    void should_require_teacher_credentials() {
        when(userMapper.selectCount(any())).thenReturn(0L);
        RegisterRequest req = registration(1);

        assertThatThrownBy(() -> authService.register(req))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.VALIDATION_FAILED.getCode()));

        verify(smsCodeService, never()).verifyAndConsume(anyString(), anyString());
    }

    private RegisterRequest registration(int role) {
        RegisterRequest req = new RegisterRequest();
        req.setUsername(role == 1 ? "teacher02" : "student02");
        req.setPassword("study2026");
        req.setRealName(role == 1 ? "李老师" : "李同学");
        req.setPhone("18500000003");
        req.setCode("123456");
        req.setRole(role);
        req.setSchoolName("测试医科大学");
        if (role == 0) {
            req.setGrade("大四");
            req.setClassName("临床2101班");
        }
        return req;
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

    @Test
    @DisplayName("login 待审核教师 -> 不签发 token")
    void should_reject_pending_teacher_login() {
        SysUser user = new SysUser();
        user.setId(10L);
        user.setUsername("teacher02");
        user.setPasswordHash("$2a$10$hash");
        user.setRole(1);
        user.setStatus(0);
        user.setAuditStatus(1);
        when(userMapper.selectOne(any())).thenReturn(user);
        when(passwordEncoder.matches("study2026", user.getPasswordHash())).thenReturn(true);

        LoginRequest req = new LoginRequest();
        req.setUsername("teacher02");
        req.setPassword("study2026");

        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.TEACHER_AUDIT_PENDING.getCode()));
        verify(jwtUtils, never()).issueToken(anyLong(), anyString(), anyInt(), anyInt());
    }

    @Test
    @DisplayName("login 管理员成功 -> 签发保留真实角色的 Web 管理 Token")
    void should_allow_admin_login_for_web_console() {
        SysUser user = new SysUser();
        user.setId(30L);
        user.setUsername("admin01");
        user.setPasswordHash("$2a$10$hash");
        user.setRole(4);
        user.setStatus(0);
        user.setAuditStatus(2);
        when(userMapper.selectOne(any())).thenReturn(user);
        when(passwordEncoder.matches("123456", user.getPasswordHash())).thenReturn(true);
        when(userMapper.updateById(any())).thenReturn(1);
        when(jwtUtils.issueToken(30L, "admin01", 4, 2)).thenReturn("admin-token");
        when(jwtUtils.issueRefreshToken(30L)).thenReturn("admin-refresh");
        when(jwtUtils.getAccessExpireMs()).thenReturn(3600_000L);

        LoginRequest req = new LoginRequest();
        req.setUsername("admin01");
        req.setPassword("123456");

        LoginResponse response = authService.login(req);

        assertThat(response.getToken()).isEqualTo("admin-token");
        assertThat(response.getRole()).isEqualTo(4);
    }

    @Test
    @DisplayName("smsLogin 验证码正确 -> 按手机号返回真实用户角色")
    void should_login_by_sms_code() {
        SysUser user = studentUser();
        user.setPhone("18500000002");
        when(userMapper.selectOne(any())).thenReturn(user);
        when(jwtUtils.issueToken(1L, "student01", 0, 0)).thenReturn("access-token");
        when(jwtUtils.issueRefreshToken(1L)).thenReturn("refresh-token");
        when(jwtUtils.getAccessExpireMs()).thenReturn(3600_000L);

        SmsLoginRequest req = new SmsLoginRequest();
        req.setPhone("18500000002");
        req.setCode("123456");

        LoginResponse resp = authService.smsLogin(req);

        verify(smsCodeService).verifyAndConsume("18500000002", "123456");
        assertThat(resp.getRole()).isZero();
        assertThat(resp.getUsername()).isEqualTo("student01");
    }

    @Test
    @DisplayName("smsLogin 未绑定手机号 -> 不签发 token")
    void should_reject_unknown_phone() {
        when(userMapper.selectOne(any())).thenReturn(null);
        SmsLoginRequest req = new SmsLoginRequest();
        req.setPhone("18500000999");
        req.setCode("123456");

        assertThatThrownBy(() -> authService.smsLogin(req))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.PHONE_OR_CODE_ERROR.getCode()));

        verify(jwtUtils, never()).issueRefreshToken(anyLong());
    }
}
