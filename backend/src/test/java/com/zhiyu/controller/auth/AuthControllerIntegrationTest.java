package com.zhiyu.controller.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.config.MyBatisTestConfig;
import com.zhiyu.service.AuthService;
import com.zhiyu.service.SmsCodeService;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.service.dto.SmsLoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.RegistrationResponse;
import com.zhiyu.vo.SmsCodeResponse;
import com.zhiyu.vo.UserInfoVO;
import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 认证接口集成测试（@WebMvcTest + 拦截器 + @MockBean Service）
 */
@DisplayName("认证接口 AuthController 集成测试")
@WebMvcTest(AuthController.class)
@Import(MyBatisTestConfig.class)
class AuthControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private AuthService authService;

    @MockBean
    private JwtUtils jwtUtils;

    @MockBean
    private SmsCodeService smsCodeService;

    @Test
    @DisplayName("POST /register 学生注册成功 -> 无需 token 并返回注册结果")
    void should_register_student_without_token() throws Exception {
        when(authService.register(any())).thenReturn(RegistrationResponse.builder()
                .userId(21L).username("student02").role(0).auditStatus(0)
                .message("注册成功，请使用新账号登录").build());

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"student02\",\"password\":\"study2026\","
                                + "\"realName\":\"李同学\",\"phone\":\"18500000003\","
                                + "\"code\":\"123456\",\"role\":0}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.userId").value(21))
                .andExpect(jsonPath("$.data.role").value(0));
    }

    @Test
    @DisplayName("POST /register 弱密码 -> 400 validation error")
    void should_reject_weak_registration_password() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"student02\",\"password\":\"12345678\","
                                + "\"realName\":\"李同学\",\"phone\":\"18500000003\","
                                + "\"code\":\"123456\",\"role\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(1422));
    }

    // ==================== POST /api/v1/auth/login ====================

    @Test
    @DisplayName("POST /login 成功 → 200, R<LoginResponse>")
    void should_return_login_response_when_success() throws Exception {
        LoginResponse resp = LoginResponse.builder()
                .token("mock-access-token")
                .refreshToken("mock-refresh-token")
                .expiresIn(3600L)
                .userId(1L)
                .username("student01")
                .realName("张三")
                .role(0)
                .auditStatus(0)
                .build();
        when(authService.login(any(LoginRequest.class))).thenReturn(resp);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"student01\",\"password\":\"123456\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.token").value("mock-access-token"))
                .andExpect(jsonPath("$.data.userId").value(1))
                .andExpect(jsonPath("$.data.username").value("student01"));
    }

    @Test
    @DisplayName("POST /login 用户名密码错误 → 200, R.fail code=2001")
    void should_return_error_when_credentials_wrong() throws Exception {
        when(authService.login(any(LoginRequest.class)))
                .thenThrow(new BizException(ResultCode.USERNAME_OR_PASSWORD_ERROR));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"student01\",\"password\":\"wrong\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(2001));
    }

    @Test
    @DisplayName("POST /login 参数校验失败（username 为空）→ 400, R.fail code=1422")
    void should_return_validation_error_when_username_blank() throws Exception {
        // 注意：GlobalExceptionHandler 对 MethodArgumentNotValidException
        // 标注了 @ResponseStatus(HttpStatus.BAD_REQUEST)，因此 HTTP 状态码为 400
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"\",\"password\":\"123456\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(1422));
    }

    @Test
    @DisplayName("POST /login/password 与兼容登录返回相同契约")
    void should_login_from_explicit_password_endpoint() throws Exception {
        when(authService.login(any(LoginRequest.class))).thenReturn(LoginResponse.builder()
                .token("password-token").refreshToken("refresh").expiresIn(3600)
                .userId(1L).username("student01").role(0).auditStatus(0).build());

        mockMvc.perform(post("/api/v1/auth/login/password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"student01\",\"password\":\"123456\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").value("password-token"))
                .andExpect(jsonPath("$.data.role").value(0));
    }

    @Test
    @DisplayName("POST /sms-code 开发模式返回 devCode")
    void should_request_sms_code() throws Exception {
        when(smsCodeService.sendCode("18500000002"))
                .thenReturn(new SmsCodeResponse(true, 300, "654321"));

        mockMvc.perform(post("/api/v1/auth/sms-code")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phone\":\"18500000002\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sent").value(true))
                .andExpect(jsonPath("$.data.devCode").value("654321"));
    }

    @Test
    @DisplayName("POST /login/sms 返回后端真实角色")
    void should_login_by_sms_code() throws Exception {
        when(authService.smsLogin(any(SmsLoginRequest.class))).thenReturn(LoginResponse.builder()
                .token("sms-token").refreshToken("refresh").expiresIn(3600)
                .userId(10L).username("teacher01").role(1).auditStatus(2).build());

        mockMvc.perform(post("/api/v1/auth/login/sms")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phone\":\"18500000001\",\"code\":\"123456\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").value("sms-token"))
                .andExpect(jsonPath("$.data.role").value(1));
    }

    // ==================== GET /api/v1/auth/me ====================

    @Test
    @DisplayName("GET /me 无 token → 200, R.fail code=1001")
    void should_return_unauthorized_when_no_token() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1001));
    }

    @Test
    @DisplayName("GET /me 有效 token → 200, R<UserInfoVO>")
    void should_return_user_info_when_token_valid() throws Exception {
        // 模拟 JWT 解析返回的用户信息
        Claims claims = org.mockito.Mockito.mock(Claims.class);
        when(claims.getSubject()).thenReturn("1");
        when(claims.get("type", String.class)).thenReturn("access");
        when(claims.get("username", String.class)).thenReturn("student01");
        when(claims.get("role", Integer.class)).thenReturn(0);
        when(claims.get("auditStatus", Integer.class)).thenReturn(0);
        when(jwtUtils.parseToken(anyString())).thenReturn(claims);

        UserInfoVO userInfo = UserInfoVO.builder()
                .id(1L)
                .username("student01")
                .realName("张三")
                .role(0)
                .auditStatus(0)
                .status(0)
                .build();
        when(authService.currentUser(anyLong())).thenReturn(userInfo);

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer mock-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.username").value("student01"))
                .andExpect(jsonPath("$.data.id").value(1));
    }
}
