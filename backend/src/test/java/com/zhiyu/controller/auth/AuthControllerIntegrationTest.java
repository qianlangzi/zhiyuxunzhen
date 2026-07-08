package com.zhiyu.controller.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.config.MyBatisTestConfig;
import com.zhiyu.service.AuthService;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.vo.LoginResponse;
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
