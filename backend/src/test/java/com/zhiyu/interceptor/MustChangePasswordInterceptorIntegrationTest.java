package com.zhiyu.interceptor;

import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.config.MyBatisTestConfig;
import com.zhiyu.controller.TestPermissionController;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 强制改密拦截器集成测试 — 验证 MustChangePasswordInterceptor 的安全边界
 *
 * <p>核心场景（Issue1 P0）：
 * <ul>
 *   <li>mustChangePassword=true 的用户访问业务接口 → 2015 PASSWORD_CHANGE_REQUIRED</li>
 *   <li>mustChangePassword=true 的用户访问白名单端点 → 放行（改密/me/logout/refresh）</li>
 *   <li>mustChangePassword=false 的用户 → 正常放行</li>
 *   <li>mustChangePassword=null → fail-closed 视为需要改密 → 2015</li>
 *   <li>credentialVersion 不匹配（旧 token）→ 1001 UNAUTHORIZED（撤销旧凭证）</li>
 * </ul>
 *
 * <p>关键安全验证：用户拿临时密码登录取得 JWT 后，不能绕过 App 直接调用
 * /api/v1/student/** 等业务接口；改密后旧 token 因版本不匹配被拒绝。
 */
@DisplayName("强制改密拦截器 MustChangePasswordInterceptor 安全边界测试")
@WebMvcTest(controllers = TestPermissionController.class)
@Import(MyBatisTestConfig.class)
class MustChangePasswordInterceptorIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private JwtUtils jwtUtils;

    @MockBean
    private SysUserMapper userMapper;

    /** 模拟 JWT 解析返回学生用户，携带指定凭证版本 */
    private void mockJwtStudent(Long userId, Integer credentialVersion) {
        Claims claims = org.mockito.Mockito.mock(Claims.class);
        when(claims.getSubject()).thenReturn(String.valueOf(userId));
        when(claims.get("type", String.class)).thenReturn("access");
        when(claims.get("username", String.class)).thenReturn("student01");
        when(claims.get("role", Integer.class)).thenReturn(0);
        when(claims.get("auditStatus", Integer.class)).thenReturn(0);
        when(claims.get("credentialVersion", Integer.class)).thenReturn(credentialVersion);
        when(jwtUtils.parseToken(org.mockito.ArgumentMatchers.anyString())).thenReturn(claims);
    }

    /** 模拟数据库查询返回指定 mustChangePassword 状态与凭证版本的用户 */
    private void mockDbUser(Long userId, Boolean mustChangePassword, Integer credentialVersion) {
        SysUser user = new SysUser();
        user.setId(userId);
        user.setMustChangePassword(mustChangePassword);
        user.setCredentialVersion(credentialVersion);
        user.setRole(0);
        user.setStatus(0);
        when(userMapper.selectById(anyLong())).thenReturn(user);
    }

    // ==================== 业务接口拦截（mustChangePassword=true） ====================

    @Test
    @DisplayName("mustChangePassword=true 访问 /student/test → 2015")
    void should_block_student_when_must_change_password() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, true, 0);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(2015));
    }

    @Test
    @DisplayName("mustChangePassword=true 访问 /admin/test → 2015（管理员路径也拦截）")
    void should_block_admin_path_when_must_change_password() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, true, 0);

        mockMvc.perform(get("/api/v1/admin/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(2015));
    }

    // ==================== 凭证版本校验（撤销旧 token） ====================

    @Test
    @DisplayName("credentialVersion 不匹配（token=0, db=1）→ 1001 凭证已失效")
    void should_block_when_credential_version_mismatch() throws Exception {
        // 攻击者持有的旧 token 版本=0，但用户已改密、DB 版本递增为 1
        mockJwtStudent(1L, 0);
        mockDbUser(1L, false, 1);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1001));
    }

    @Test
    @DisplayName("token 中 credentialVersion=null → 1001 凭证已失效")
    void should_block_when_token_version_null() throws Exception {
        mockJwtStudent(1L, null);
        mockDbUser(1L, false, 0);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1001));
    }

    @Test
    @DisplayName("DB 中 credentialVersion=null → 1001 凭证已失效（fail-closed）")
    void should_block_when_db_version_null() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, false, null);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1001));
    }

    @Test
    @DisplayName("credentialVersion 不匹配访问白名单 /auth/me → 1001（版本校验在白名单之前）")
    void should_block_whitelisted_endpoint_when_version_mismatch() throws Exception {
        // 改密后旧 token 版本=0，DB 版本=1。旧 token 不应访问任何端点（含白名单）。
        // 这验证版本校验位于白名单之前，防止旧 token 通过 /auth/me 等白名单端点读取用户信息。
        mockJwtStudent(1L, 0);
        mockDbUser(1L, false, 1);

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1001));
    }

    // ==================== 白名单放行 ====================

    @Test
    @DisplayName("mustChangePassword=true PUT /auth/password → 放行(0)")
    void should_allow_change_password_when_must_change() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, true, 0);

        mockMvc.perform(put("/api/v1/auth/password")
                        .header("Authorization", "Bearer token")
                        .contentType("application/json")
                        .content("{\"oldPassword\":\"a\",\"newPassword\":\"b\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("mustChangePassword=true GET /auth/me → 放行(0)")
    void should_allow_get_me_when_must_change() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, true, 0);

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("mustChangePassword=true POST /auth/logout → 放行(0)")
    void should_allow_logout_when_must_change() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, true, 0);

        mockMvc.perform(post("/api/v1/auth/logout")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("mustChangePassword=true POST /auth/refresh → 放行(0)")
    void should_allow_refresh_when_must_change() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, true, 0);

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .header("Authorization", "Bearer token")
                        .contentType("application/json")
                        .content("{\"refreshToken\":\"xxx\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    // ==================== 正常用户放行 ====================

    @Test
    @DisplayName("mustChangePassword=false 访问 /student/test → 放行(0)")
    void should_allow_student_when_password_changed() throws Exception {
        mockJwtStudent(1L, 0);
        mockDbUser(1L, false, 0);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("mustChangePassword=null 访问 /student/test → 2015（fail-closed）")
    void should_block_student_when_must_change_null() throws Exception {
        // 安全边界不信任 null：mustChangePassword=null 视为需要改密
        mockJwtStudent(1L, 0);
        mockDbUser(1L, null, 0);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(2015));
    }

    // ==================== JWT 绕过场景 ====================

    @Test
    @DisplayName("mustChangePassword=true 直接带 JWT 访问 /teacher/test → 2015（防绕过）")
    void should_block_teacher_api_when_must_change_password() throws Exception {
        // 模拟用户拿临时密码登录取得 JWT 后直接调用教师接口
        mockJwtStudent(1L, 0);
        mockDbUser(1L, true, 0);

        mockMvc.perform(post("/api/v1/teacher/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(2015));
    }
}
