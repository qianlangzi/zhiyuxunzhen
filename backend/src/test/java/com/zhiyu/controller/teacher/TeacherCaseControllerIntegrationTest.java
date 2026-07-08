package com.zhiyu.controller.teacher;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.config.MyBatisTestConfig;
import com.zhiyu.service.TeacherCaseService;
import com.zhiyu.service.dto.CaseCreateDTO;
import com.zhiyu.vo.TeacherCaseListVO;
import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 教师病例接口集成测试（@WebMvcTest + 拦截器 + @MockBean Service）
 */
@DisplayName("教师病例接口 TeacherCaseController 集成测试")
@WebMvcTest(TeacherCaseController.class)
@Import(MyBatisTestConfig.class)
class TeacherCaseControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private TeacherCaseService teacherCaseService;

    @MockBean
    private JwtUtils jwtUtils;

    private static final String VALID_CASE_JSON =
            "{\"title\":\"测试病例\",\"department\":\"内科\",\"difficulty\":2,"
                    + "\"patientProfile\":\"{\\\"age\\\":30}\",\"hiddenDisease\":\"流感\","
                    + "\"standardPathJson\":\"{}\"}";

    /** 模拟 JWT 解析返回指定角色的用户 */
    private void mockJwtUser(Long userId, String username, Integer role, Integer auditStatus) {
        Claims claims = org.mockito.Mockito.mock(Claims.class);
        when(claims.getSubject()).thenReturn(String.valueOf(userId));
        when(claims.get("type", String.class)).thenReturn("access");
        when(claims.get("username", String.class)).thenReturn(username);
        when(claims.get("role", Integer.class)).thenReturn(role);
        when(claims.get("auditStatus", Integer.class)).thenReturn(auditStatus);
        when(jwtUtils.parseToken(anyString())).thenReturn(claims);
    }

    // ==================== POST /api/v1/teacher/cases ====================

    @Test
    @DisplayName("POST /teacher/cases 无 token → 200, R.fail code=1001")
    void should_return_unauthorized_when_no_token() throws Exception {
        mockMvc.perform(post("/api/v1/teacher/cases")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_CASE_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1001));
    }

    @Test
    @DisplayName("POST /teacher/cases 学生 token → 200, R.fail code=1003")
    void should_return_forbidden_when_student_token() throws Exception {
        mockJwtUser(1L, "student01", 0, 0);

        mockMvc.perform(post("/api/v1/teacher/cases")
                        .header("Authorization", "Bearer student-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_CASE_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(1003));
    }

    @Test
    @DisplayName("POST /teacher/cases 教师但 audit_status≠2 → 200, R.fail code=2003")
    void should_return_not_audited_when_teacher_audit_not_2() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 0);

        mockMvc.perform(post("/api/v1/teacher/cases")
                        .header("Authorization", "Bearer teacher-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_CASE_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(2003));
    }

    @Test
    @DisplayName("POST /teacher/cases 教师已认证（audit=2）→ 200, R<Long>")
    void should_create_case_when_teacher_audited() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 2);
        when(teacherCaseService.create(any(CaseCreateDTO.class))).thenReturn(1L);

        mockMvc.perform(post("/api/v1/teacher/cases")
                        .header("Authorization", "Bearer teacher-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_CASE_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data").value(1));
    }

    // ==================== GET /api/v1/teacher/cases ====================

    @Test
    @DisplayName("GET /teacher/cases 教师已认证 → 200, R<PageResult>")
    void should_return_cases_when_teacher_audited() throws Exception {
        mockJwtUser(10L, "teacher01", 1, 2);

        TeacherCaseListVO vo = TeacherCaseListVO.builder()
                .id(1L)
                .title("我的病例")
                .department("内科")
                .difficulty(2)
                .status(0)
                .adminAuditStatus(0)
                .referenceCount(0)
                .isPublic(false)
                .build();
        PageResult<TeacherCaseListVO> pageResult = PageResult.of(List.of(vo), 1, 1, 10);
        when(teacherCaseService.myCases(any(), any(), any(), any())).thenReturn(pageResult);

        mockMvc.perform(get("/api/v1/teacher/cases")
                        .header("Authorization", "Bearer teacher-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.list[0].title").value("我的病例"));
    }

    @Test
    @DisplayName("GET /teacher/cases 教师 audit=0（GET 不检查 audit）→ 200, R<PageResult>")
    void should_allow_get_when_teacher_audit_not_2() throws Exception {
        // GET 请求不检查 audit_status，教师未审核也可以查看列表
        mockJwtUser(10L, "teacher01", 1, 0);

        PageResult<TeacherCaseListVO> pageResult = PageResult.of(List.of(), 0, 1, 10);
        when(teacherCaseService.myCases(any(), any(), any(), any())).thenReturn(pageResult);

        mockMvc.perform(get("/api/v1/teacher/cases")
                        .header("Authorization", "Bearer teacher-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }
}
