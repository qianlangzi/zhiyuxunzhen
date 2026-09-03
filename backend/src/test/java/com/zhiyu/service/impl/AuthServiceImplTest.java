package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.SmsCodeService;
import com.zhiyu.service.dto.ChangePasswordRequest;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.service.dto.RegisterRequest;
import com.zhiyu.service.dto.SmsLoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.RegistrationResponse;
import org.junit.jupiter.api.AfterEach;
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
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
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

    @Mock
    private AuditLogService auditLogService;

    @InjectMocks
    private AuthServiceImpl authService;

    /** changePassword 使用 UserContext.get().getCredentialVersion() 做 CAS，测试后必须清理 ThreadLocal */
    @AfterEach
    void clearUserContext() {
        UserContext.clear();
    }

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
        when(jwtUtils.issueToken(1L, "student01", 0, 0, 0)).thenReturn("access-token");
        when(jwtUtils.issueRefreshToken(1L, 0)).thenReturn("refresh-token");
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
        when(jwtUtils.issueToken(10L, "teacher01", 1, 0, 0)).thenReturn("teacher-token");
        when(jwtUtils.issueRefreshToken(10L, 0)).thenReturn("teacher-refresh");
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
        verify(jwtUtils, never()).issueToken(anyLong(), anyString(), anyInt(), anyInt(), anyInt());
    }

    @Test
    @DisplayName("login 被驳回教师 -> 允许登录并签发 token（P1-2: 解除死锁）")
    void should_allow_rejected_teacher_login() {
        SysUser user = new SysUser();
        user.setId(11L);
        user.setUsername("teacher03");
        user.setPasswordHash("$2a$10$hash");
        user.setRole(1);
        user.setStatus(0);
        user.setAuditStatus(3); // 驳回
        when(userMapper.selectOne(any())).thenReturn(user);
        when(passwordEncoder.matches("study2026", user.getPasswordHash())).thenReturn(true);
        when(jwtUtils.issueToken(11L, "teacher03", 1, 3, 0)).thenReturn("access");
        when(jwtUtils.issueRefreshToken(11L, 0)).thenReturn("refresh");
        when(jwtUtils.getAccessExpireMs()).thenReturn(3600_000L);

        LoginRequest req = new LoginRequest();
        req.setUsername("teacher03");
        req.setPassword("study2026");

        LoginResponse resp = authService.login(req);
        assertThat(resp.getToken()).isEqualTo("access");
        assertThat(resp.getAuditStatus()).isEqualTo(3);
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
        when(jwtUtils.issueToken(30L, "admin01", 4, 2, 0)).thenReturn("admin-token");
        when(jwtUtils.issueRefreshToken(30L, 0)).thenReturn("admin-refresh");
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
        when(jwtUtils.issueToken(1L, "student01", 0, 0, 0)).thenReturn("access-token");
        when(jwtUtils.issueRefreshToken(1L, 0)).thenReturn("refresh-token");
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

        verify(jwtUtils, never()).issueRefreshToken(anyLong(), anyInt());
    }

    // ---------- changePassword ----------

    /** 构造改密请求 */
    private ChangePasswordRequest changeReq(String oldPwd, String newPwd) {
        ChangePasswordRequest req = new ChangePasswordRequest();
        req.setOldPassword(oldPwd);
        req.setNewPassword(newPwd);
        return req;
    }

    @Test
    @DisplayName("changePassword 原密码正确且新密码不同 -> CAS 更新哈希+递增版本+清标志+签发新 token")
    void should_change_password_when_old_correct_and_new_different() {
        SysUser user = studentUser();
        user.setMustChangePassword(true);
        // credentialVersion=null → newVersion = 0+1 = 1
        when(userMapper.selectById(1L)).thenReturn(user);
        // 原密码校验通过
        when(passwordEncoder.matches("Temp1234", user.getPasswordHash())).thenReturn(true);
        // 新密码与原密码不同
        when(passwordEncoder.matches("NewPass123", user.getPasswordHash())).thenReturn(false);
        when(passwordEncoder.encode("NewPass123")).thenReturn("new-hash");
        // CAS 更新成功
        when(userMapper.update(isNull(), any())).thenReturn(1);
        // 新 token 携带递增后的版本 1
        when(jwtUtils.issueToken(1L, "student01", 0, 0, 1)).thenReturn("new-access");
        when(jwtUtils.issueRefreshToken(1L, 1)).thenReturn("new-refresh");
        when(jwtUtils.getAccessExpireMs()).thenReturn(3600_000L);

        // P0-1: changePassword 使用 token 中的 credentialVersion 做 CAS，需设置 UserContext
        UserContext.set(UserContext.LoginUser.builder().userId(1L).credentialVersion(0).build());

        LoginResponse resp = authService.changePassword(1L, changeReq("Temp1234", "NewPass123"));

        // 验证返回了新 token（客户端用它替换旧 token）
        assertThat(resp).isNotNull();
        assertThat(resp.getToken()).isEqualTo("new-access");
        assertThat(resp.getRefreshToken()).isEqualTo("new-refresh");
        assertThat(resp.getMustChangePassword()).isFalse();

        // 验证 CAS 更新被调用（条件: id + 旧 passwordHash）
        verify(userMapper).update(isNull(), any());
        // 验证审计日志已记录（不含密码明文，含新版本号）
        verify(auditLogService).record(eq("change_password"), eq("user"), eq(1L), isNull(), anyString());
    }

    @Test
    @DisplayName("changePassword credentialVersion=5 → 递增为 6，新 token 携带版本 6")
    void should_increment_credential_version_from_existing() {
        SysUser user = studentUser();
        user.setMustChangePassword(false);
        user.setCredentialVersion(5);
        when(userMapper.selectById(1L)).thenReturn(user);
        when(passwordEncoder.matches("Old1234", user.getPasswordHash())).thenReturn(true);
        when(passwordEncoder.matches("NewPass123", user.getPasswordHash())).thenReturn(false);
        when(passwordEncoder.encode("NewPass123")).thenReturn("new-hash");
        when(userMapper.update(isNull(), any())).thenReturn(1);
        // 新 token 必须携带版本 6（5+1）
        when(jwtUtils.issueToken(1L, "student01", 0, 0, 6)).thenReturn("v6-access");
        when(jwtUtils.issueRefreshToken(1L, 6)).thenReturn("v6-refresh");
        when(jwtUtils.getAccessExpireMs()).thenReturn(3600_000L);

        // P0-1: token 中的 credentialVersion=5，CAS 校验 .eq("credential_version", 5)，递增为 6
        UserContext.set(UserContext.LoginUser.builder().userId(1L).credentialVersion(5).build());

        LoginResponse resp = authService.changePassword(1L, changeReq("Old1234", "NewPass123"));

        assertThat(resp.getToken()).isEqualTo("v6-access");
        assertThat(resp.getRefreshToken()).isEqualTo("v6-refresh");
        verify(jwtUtils).issueToken(1L, "student01", 0, 0, 6);
        verify(jwtUtils).issueRefreshToken(1L, 6);
    }

    @Test
    @DisplayName("changePassword CAS 失败（并发改密）→ BizException(VALIDATION_FAILED)，不签发新 token")
    void should_throw_when_cas_update_fails_due_to_concurrent_modification() {
        SysUser user = studentUser();
        when(userMapper.selectById(1L)).thenReturn(user);
        when(passwordEncoder.matches("Temp1234", user.getPasswordHash())).thenReturn(true);
        when(passwordEncoder.matches("NewPass123", user.getPasswordHash())).thenReturn(false);
        // CAS 更新返回 0 行（旧密码 hash 已被并发请求修改）
        when(userMapper.update(isNull(), any())).thenReturn(0);

        // P0-1: changePassword 使用 token 中的 credentialVersion 做 CAS，需设置 UserContext
        UserContext.set(UserContext.LoginUser.builder().userId(1L).credentialVersion(0).build());

        assertThatThrownBy(() -> authService.changePassword(1L, changeReq("Temp1234", "NewPass123")))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.VALIDATION_FAILED.getCode()));

        // CAS 失败不应签发新 token
        verify(jwtUtils, never()).issueToken(anyLong(), anyString(), anyInt(), anyInt(), anyInt());
        verify(jwtUtils, never()).issueRefreshToken(anyLong(), anyInt());
        verify(auditLogService, never()).record(anyString(), anyString(), anyLong(), any(), any());
    }

    @Test
    @DisplayName("changePassword 原密码错误 -> BizException(VALIDATION_FAILED)，不更新")
    void should_throw_when_old_password_wrong() {
        SysUser user = studentUser();
        when(userMapper.selectById(1L)).thenReturn(user);
        when(passwordEncoder.matches("wrong", user.getPasswordHash())).thenReturn(false);

        assertThatThrownBy(() -> authService.changePassword(1L, changeReq("wrong", "NewPass123")))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.VALIDATION_FAILED.getCode()));

        verify(userMapper, never()).update(any(), any());
        verify(auditLogService, never()).record(anyString(), anyString(), anyLong(), any(), any());
    }

    @Test
    @DisplayName("changePassword 新密码与原密码相同 -> BizException(PASSWORD_SAME_AS_OLD)")
    void should_throw_when_new_password_same_as_old() {
        SysUser user = studentUser();
        when(userMapper.selectById(1L)).thenReturn(user);
        // 原密码正确，但新密码也匹配原哈希（即相同）
        when(passwordEncoder.matches("Same1234", user.getPasswordHash())).thenReturn(true);

        assertThatThrownBy(() -> authService.changePassword(1L, changeReq("Same1234", "Same1234")))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.PASSWORD_SAME_AS_OLD.getCode()));

        verify(userMapper, never()).update(any(), any());
        verify(auditLogService, never()).record(anyString(), anyString(), anyLong(), any(), any());
    }

    @Test
    @DisplayName("changePassword 用户不存在 -> BizException(NOT_FOUND)")
    void should_throw_when_user_not_found_on_change_password() {
        when(userMapper.selectById(99L)).thenReturn(null);

        assertThatThrownBy(() -> authService.changePassword(99L, changeReq("old", "NewPass123")))
                .isInstanceOf(BizException.class)
                .satisfies(ex -> assertThat(((BizException) ex).getCode())
                        .isEqualTo(ResultCode.NOT_FOUND.getCode()));

        verify(passwordEncoder, never()).matches(anyString(), anyString());
        verify(userMapper, never()).update(any(), any());
    }
}
