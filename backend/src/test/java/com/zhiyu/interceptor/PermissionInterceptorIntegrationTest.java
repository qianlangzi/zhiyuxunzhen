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
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 权限拦截器集成测试 — 测试 PermissionInterceptor 的 RBAC 矩阵
 * 使用 TestPermissionController 提供各路径前缀的测试端点
 */
@DisplayName("权限拦截器 PermissionInterceptor RBAC 矩阵测试")
@WebMvcTest(controllers = TestPermissionController.class)
@Import(MyBatisTestConfig.class)
class PermissionInterceptorIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private JwtUtils jwtUtils;

    @MockBean
    private SysUserMapper userMapper;

    /** 模拟 JWT 解析返回指定角色的用户，并 mock 数据库返回 mustChangePassword=false 的用户
     *
     * 注意：MustChangePasswordInterceptor 在 PermissionInterceptor 之前执行（order=15 < 20），
     * 会调用 userMapper.selectById 查库。若不 mock，RBAC 测试会被 1001/2015 阻断而非返回预期的 1003/0。
     * 必须同时设置 credentialVersion（token 与 DB 一致），否则版本校验返回 1001。
     */
    private void mockJwtUser(Long userId, String username, Integer role, Integer auditStatus) {
        Claims claims = org.mockito.Mockito.mock(Claims.class);
        when(claims.getSubject()).thenReturn(String.valueOf(userId));
        when(claims.get("type", String.class)).thenReturn("access");
        when(claims.get("username", String.class)).thenReturn(username);
        when(claims.get("role", Integer.class)).thenReturn(role);
        when(claims.get("auditStatus", Integer.class)).thenReturn(auditStatus);
        when(claims.get("credentialVersion", Integer.class)).thenReturn(0);
        when(jwtUtils.parseToken(anyString())).thenReturn(claims);

        // mock 数据库用户：mustChangePassword=false + credentialVersion=0（与 token 一致），
        // 确保 MustChangePasswordInterceptor 放行，让请求到达 PermissionInterceptor 以测试 RBAC 逻辑
        SysUser user = new SysUser();
        user.setId(userId);
        user.setMustChangePassword(false);
        user.setCredentialVersion(0);
        user.setRole(role);
        user.setStatus(0);
        when(userMapper.selectById(anyLong())).thenReturn(user);
    }

    // ==================== /api/v1/admin/** ====================

    @Test
    @DisplayName("学生(0) 访问 /admin → FORBIDDEN(1003)")
    void should_forbid_student_access_admin() throws Exception {
        mockJwtUser(1L, "student01", 0, 0);

        mockMvc.perform(get("/api/v1/admin/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    @Test
    @DisplayName("管理员(4) 访问 /admin → 通过(0)")
    void should_allow_admin_access_admin() throws Exception {
        mockJwtUser(2L, "admin01", 4, null);

        mockMvc.perform(get("/api/v1/admin/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    // ==================== POST /api/v1/admin/users/import 精确矩阵 ====================
    // 教学秘书(2) / 管理员(4) 可访问，其余角色拒绝

    @Test
    @DisplayName("教学秘书(2) POST /admin/users/import → 通过(0)")
    void should_allow_teaching_secretary_import_users() throws Exception {
        mockJwtUser(20L, "secretary01", 2, null);

        mockMvc.perform(post("/api/v1/admin/users/import")
                        .header("Authorization", "Bearer token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("管理员(4) POST /admin/users/import → 通过(0)")
    void should_allow_admin_import_users() throws Exception {
        mockJwtUser(2L, "admin01", 4, null);

        mockMvc.perform(post("/api/v1/admin/users/import")
                        .header("Authorization", "Bearer token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("教研室主任(3) POST /admin/users/import → FORBIDDEN(1003)")
    void should_forbid_dept_head_import_users() throws Exception {
        mockJwtUser(30L, "depthead01", 3, null);

        mockMvc.perform(post("/api/v1/admin/users/import")
                        .header("Authorization", "Bearer token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    @Test
    @DisplayName("运维(5) POST /admin/users/import → FORBIDDEN(1003)")
    void should_forbid_ops_import_users() throws Exception {
        mockJwtUser(50L, "ops01", 5, null);

        mockMvc.perform(post("/api/v1/admin/users/import")
                        .header("Authorization", "Bearer token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    @Test
    @DisplayName("学生(0) POST /admin/users/import → FORBIDDEN(1003)")
    void should_forbid_student_import_users() throws Exception {
        mockJwtUser(1L, "student01", 0, 0);

        mockMvc.perform(post("/api/v1/admin/users/import")
                        .header("Authorization", "Bearer token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    // ==================== GET /api/v1/admin/dashboard 精确矩阵 ====================
    // 教研室主任(3) / 管理员(4) / 运维(5) 可访问，其余角色拒绝

    @Test
    @DisplayName("教研室主任(3) GET /admin/dashboard → 通过(0)")
    void should_allow_dept_head_access_dashboard() throws Exception {
        mockJwtUser(30L, "depthead01", 3, null);

        mockMvc.perform(get("/api/v1/admin/dashboard")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("管理员(4) GET /admin/dashboard → 通过(0)")
    void should_allow_admin_access_dashboard() throws Exception {
        mockJwtUser(2L, "admin01", 4, null);

        mockMvc.perform(get("/api/v1/admin/dashboard")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("运维(5) GET /admin/dashboard → 通过(0)")
    void should_allow_ops_access_dashboard() throws Exception {
        mockJwtUser(50L, "ops01", 5, null);

        mockMvc.perform(get("/api/v1/admin/dashboard")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("教学秘书(2) GET /admin/dashboard → FORBIDDEN(1003)")
    void should_forbid_teaching_secretary_access_dashboard() throws Exception {
        mockJwtUser(20L, "secretary01", 2, null);

        mockMvc.perform(get("/api/v1/admin/dashboard")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    @Test
    @DisplayName("学生(0) GET /admin/dashboard → FORBIDDEN(1003)")
    void should_forbid_student_access_dashboard() throws Exception {
        mockJwtUser(1L, "student01", 0, 0);

        mockMvc.perform(get("/api/v1/admin/dashboard")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    // ==================== /api/v1/teacher/** ====================

    @Test
    @DisplayName("学生(0) 访问 /teacher → FORBIDDEN(1003)")
    void should_forbid_student_access_teacher() throws Exception {
        mockJwtUser(1L, "student01", 0, 0);

        mockMvc.perform(get("/api/v1/teacher/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    @Test
    @DisplayName("教师(1, audit=2) POST /teacher → 通过(0)")
    void should_allow_audited_teacher_post_teacher() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 2);

        mockMvc.perform(post("/api/v1/teacher/test")
                        .header("Authorization", "Bearer token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("教师(1, audit=0) POST /teacher → TEACHER_NOT_AUDITED(2003)")
    void should_reject_unaudited_teacher_post_teacher() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 0);

        mockMvc.perform(post("/api/v1/teacher/test")
                        .header("Authorization", "Bearer token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(2003));
    }

    @Test
    @DisplayName("教师(1, audit=0) GET /teacher → 通过(0)（GET 不检查 audit）")
    void should_allow_unaudited_teacher_get_teacher() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 0);

        mockMvc.perform(get("/api/v1/teacher/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    // ==================== /api/v1/student/** ====================

    @Test
    @DisplayName("教师(1) 访问 /student → FORBIDDEN(1003)")
    void should_forbid_teacher_access_student() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 2);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    @Test
    @DisplayName("学生(0) 访问 /student → 通过(0)")
    void should_allow_student_access_student() throws Exception {
        mockJwtUser(1L, "student01", 0, 0);

        mockMvc.perform(get("/api/v1/student/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    // ==================== /api/v1/case-market/** ====================

    @Test
    @DisplayName("学生(0) 访问 /case-market → 通过(0)（任何登录用户可访问）")
    void should_allow_student_access_case_market() throws Exception {
        mockJwtUser(1L, "student01", 0, 0);

        mockMvc.perform(get("/api/v1/case-market/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }

    @Test
    @DisplayName("教师(1) 访问 /case-market → 通过(0)")
    void should_allow_teacher_access_case_market() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 2);

        mockMvc.perform(get("/api/v1/case-market/test")
                        .header("Authorization", "Bearer token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }
}
