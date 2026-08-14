package com.zhiyu.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.AuditLog;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.AuditLogMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.dto.TeacherAuditSubmitDTO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * 教师资质提交 CAS 单元测试（F4 补测）
 *
 * 核心验证：submitAudit 的 CAS 使用 token 携带的 credential_version（UserContext），
 * 而非服务层重读的 DB 版本。当管理员在拦截器与服务层之间冻结/驳回教师时，
 * DB 版本递增但 token 版本不变 → CAS 失败 → BizException。
 */
@DisplayName("教师资质提交 CAS — TeacherProfileServiceImpl")
@ExtendWith(MockitoExtension.class)
class TeacherProfileServiceImplTest {

    @Mock
    private SysUserMapper userMapper;

    @Mock
    private AuditLogMapper auditLogMapper;

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private ObjectMapper objectMapper;

    @InjectMocks
    private TeacherProfileServiceImpl service;

    @AfterEach
    void clearUserContext() {
        UserContext.clear();
    }

    /** 构造一个驳回状态的教师（audit_status=3, cv=5） */
    private SysUser rejectedTeacher() {
        SysUser u = new SysUser();
        u.setId(10L);
        u.setRole(1);
        u.setStatus(0);
        u.setAuditStatus(3);
        u.setCredentialVersion(5);
        return u;
    }

    private TeacherAuditSubmitDTO submitDto() {
        TeacherAuditSubmitDTO dto = new TeacherAuditSubmitDTO();
        dto.setCertificateNo("CERT-001");
        dto.setDepartment("内科");
        return dto;
    }

    @Test
    @DisplayName("token cv 与 DB cv 一致 → CAS 成功 → 提交成功")
    void should_submit_when_token_cv_matches_db() throws Exception {
        // token 携带 cv=5，DB 仍为 cv=5（无并发变更）
        UserContext.set(UserContext.LoginUser.builder()
                .userId(10L).credentialVersion(5).build());
        SysUser teacher = rejectedTeacher(); // cv=5
        when(userMapper.selectById(10L)).thenReturn(teacher);
        when(userMapper.update(any(), any())).thenReturn(1);
        when(objectMapper.writeValueAsString(any())).thenReturn("{}");

        service.submitAudit(submitDto());

        verify(userMapper).update(any(), any());
        verify(auditLogService).record(eq("teacher_audit_submit"), eq("user"), eq(10L), any(), any());
    }

    @Test
    @DisplayName("token cv=5 但 DB cv=6（管理员驳回递增）→ CAS 失败 → BizException")
    void should_reject_when_token_cv_mismatches_db() {
        // 拦截器验证时 token cv=5 与 DB cv=5 一致 → 通过
        // 但服务层执行前管理员驳回 → DB cv 递增为 6
        // CAS .eq("credential_version", 5) 不匹配 DB 的 6 → rows=0 → 拒绝
        UserContext.set(UserContext.LoginUser.builder()
                .userId(10L).credentialVersion(5).build());
        SysUser teacher = rejectedTeacher();
        teacher.setCredentialVersion(6); // DB 已递增
        when(userMapper.selectById(10L)).thenReturn(teacher);
        when(userMapper.update(any(), any())).thenReturn(0); // CAS 失败

        assertThatThrownBy(() -> service.submitAudit(submitDto()))
                .isInstanceOf(BizException.class)
                .hasMessageContaining("账号状态或凭证已变更");

        // 审计日志不应被调用（CAS 失败，无业务操作）
        verify(auditLogService, never()).record(any(), any(), any(), any(), any());
    }

    @Test
    @DisplayName("credentialVersion=null → 防御性拒绝 UNAUTHORIZED")
    void should_reject_when_credential_version_is_null() {
        // 非 HTTP 路径（测试/内部接口）调用时 credentialVersion 可能为 null
        UserContext.set(UserContext.LoginUser.builder()
                .userId(10L).credentialVersion(null).build());

        assertThatThrownBy(() -> service.submitAudit(submitDto()))
                .isInstanceOf(BizException.class)
                .hasMessageContaining("凭证已失效");

        verify(userMapper, never()).selectById(any());
        verify(userMapper, never()).update(any(), any());
    }
}
