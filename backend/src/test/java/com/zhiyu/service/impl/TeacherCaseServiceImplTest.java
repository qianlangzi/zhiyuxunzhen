package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.dto.CaseCreateDTO;
import com.zhiyu.service.dto.CaseUpdateDTO;
import com.zhiyu.vo.CasePreviewVO;
import com.zhiyu.vo.TeacherCaseListVO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.MockedStatic;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * 教师病例服务 — 单元测试（纯 Mockito + mockStatic UserContext）
 */
@DisplayName("教师病例服务 TeacherCaseServiceImpl")
@ExtendWith(MockitoExtension.class)
class TeacherCaseServiceImplTest {

    @Mock
    private SpCaseConfigMapper caseMapper;

    @Mock
    private AssignmentMapper assignmentMapper;

    @InjectMocks
    private TeacherCaseServiceImpl service;

    private CaseCreateDTO buildCreateDTO() {
        CaseCreateDTO dto = new CaseCreateDTO();
        dto.setTitle("测试病例");
        dto.setDepartment("内科");
        dto.setDifficulty(2);
        dto.setPatientProfile("{\"age\":30}");
        dto.setHiddenDisease("流感");
        dto.setStandardPathJson("{}");
        dto.setPresetExams("[]");
        dto.setKnowledgeTags("[\"发热\"]");
        return dto;
    }

    private CaseUpdateDTO buildUpdateDTO() {
        CaseUpdateDTO dto = new CaseUpdateDTO();
        dto.setTitle("更新病例");
        dto.setDepartment("外科");
        dto.setDifficulty(3);
        dto.setPatientProfile("{\"age\":40}");
        dto.setHiddenDisease("骨折");
        dto.setStandardPathJson("{}");
        return dto;
    }

    // ==================== create ====================

    @Test
    @DisplayName("create 病例 → 校验写入字段（creatorId、isPublic=false、version=1、status=0、adminAuditStatus=0）")
    void should_set_correct_fields_when_create() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            // 模拟 insert 时 MyBatis Plus 回填自增 ID
            when(caseMapper.insert(any(SpCaseConfig.class))).thenAnswer(inv -> {
                SpCaseConfig c = inv.getArgument(0);
                c.setId(999L);
                return 1;
            });

            Long id = service.create(buildCreateDTO());

            assertThat(id).isEqualTo(999L);

            ArgumentCaptor<SpCaseConfig> captor = ArgumentCaptor.forClass(SpCaseConfig.class);
            verify(caseMapper).insert(captor.capture());

            SpCaseConfig saved = captor.getValue();
            assertThat(saved.getCreatorId()).isEqualTo(100L);
            assertThat(saved.getIsPublic()).isFalse();
            assertThat(saved.getVersion()).isEqualTo(1);
            assertThat(saved.getStatus()).isEqualTo(0);
            assertThat(saved.getAdminAuditStatus()).isEqualTo(0);
            assertThat(saved.getReferenceCount()).isEqualTo(0);
            assertThat(saved.getRatingAvg()).isEqualByComparingTo(BigDecimal.ZERO);
            assertThat(saved.getTitle()).isEqualTo("测试病例");
        }
    }

    // ==================== update ====================

    @Test
    @DisplayName("update 病例（非创建者）→ BizException(FORBIDDEN)")
    void should_throw_forbidden_when_update_by_non_creator() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(200L);

            SpCaseConfig existing = new SpCaseConfig();
            existing.setId(1L);
            existing.setCreatorId(100L); // 创建者是 100，当前用户是 200
            when(caseMapper.selectById(1L)).thenReturn(existing);

            assertThatThrownBy(() -> service.update(1L, buildUpdateDTO()))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.FORBIDDEN.getCode()));

            verify(assignmentMapper, never()).selectCount(any());
            verify(caseMapper, never()).updateById(any());
        }
    }

    @Test
    @DisplayName("update 病例（不存在）→ BizException(CASE_NOT_FOUND)")
    void should_throw_when_update_nonexistent_case() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(caseMapper.selectById(1L)).thenReturn(null);

            assertThatThrownBy(() -> service.update(1L, buildUpdateDTO()))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.CASE_NOT_FOUND.getCode()));
        }
    }

    @Test
    @DisplayName("update 病例（被作业引用）→ BizException（错误码 2107）")
    void should_throw_when_case_referenced_by_assignment() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            SpCaseConfig existing = new SpCaseConfig();
            existing.setId(1L);
            existing.setCreatorId(100L);
            existing.setVersion(1);
            when(caseMapper.selectById(1L)).thenReturn(existing);
            when(assignmentMapper.selectCount(any(LambdaQueryWrapper.class))).thenReturn(1L);

            assertThatThrownBy(() -> service.update(1L, buildUpdateDTO()))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode()).isEqualTo(2107));

            verify(caseMapper, never()).updateById(any());
        }
    }

    @Test
    @DisplayName("update 病例（正常更新）→ version 递增、字段更新")
    void should_update_and_increment_version_when_valid() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            SpCaseConfig existing = new SpCaseConfig();
            existing.setId(1L);
            existing.setCreatorId(100L);
            existing.setVersion(1);
            when(caseMapper.selectById(1L)).thenReturn(existing);
            when(assignmentMapper.selectCount(any())).thenReturn(0L);
            when(caseMapper.updateById(any())).thenReturn(1);

            service.update(1L, buildUpdateDTO());

            ArgumentCaptor<SpCaseConfig> captor = ArgumentCaptor.forClass(SpCaseConfig.class);
            verify(caseMapper).updateById(captor.capture());

            SpCaseConfig updated = captor.getValue();
            assertThat(updated.getVersion()).isEqualTo(2); // 1 → 2
            assertThat(updated.getTitle()).isEqualTo("更新病例");
            assertThat(updated.getDepartment()).isEqualTo("外科");
            assertThat(updated.getDifficulty()).isEqualTo(3);
        }
    }

    // ==================== myCases ====================

    @Test
    @DisplayName("myCases 分页查询 → 返回当前教师的病例列表")
    void should_return_cases_for_current_teacher() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            SpCaseConfig record = new SpCaseConfig();
            record.setId(1L);
            record.setTitle("我的病例");
            record.setDepartment("内科");
            record.setDifficulty(2);
            record.setStatus(0);
            record.setAdminAuditStatus(0);
            record.setReferenceCount(0);
            record.setRatingAvg(BigDecimal.ZERO);
            record.setIsPublic(false);

            when(caseMapper.selectPage(any(Page.class), any())).thenAnswer(inv -> {
                Page<SpCaseConfig> p = inv.getArgument(0);
                p.setRecords(java.util.List.of(record));
                p.setTotal(1);
                return p;
            });

            PageResult<TeacherCaseListVO> result = service.myCases(1, 10, null, null, null);

            assertThat(result).isNotNull();
            assertThat(result.getTotal()).isEqualTo(1);
            assertThat(result.getList()).hasSize(1);
            assertThat(result.getList().get(0).getTitle()).isEqualTo("我的病例");
        }
    }

    // ==================== preview ====================

    @Test
    @DisplayName("preview（非创建者）→ BizException(FORBIDDEN)")
    void should_throw_forbidden_when_preview_by_non_creator() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(200L);

            SpCaseConfig existing = new SpCaseConfig();
            existing.setId(1L);
            existing.setCreatorId(100L);
            when(caseMapper.selectById(1L)).thenReturn(existing);

            assertThatThrownBy(() -> service.preview(1L))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.FORBIDDEN.getCode()));
        }
    }

    @Test
    @DisplayName("preview（不存在）→ BizException(CASE_NOT_FOUND)")
    void should_throw_when_preview_nonexistent_case() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(caseMapper.selectById(1L)).thenReturn(null);

            assertThatThrownBy(() -> service.preview(1L))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.CASE_NOT_FOUND.getCode()));
        }
    }

    @Test
    @DisplayName("preview（创建者本人）→ 返回完整预览信息")
    void should_return_preview_when_creator() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            SpCaseConfig existing = new SpCaseConfig();
            existing.setId(1L);
            existing.setCreatorId(100L);
            existing.setTitle("预览病例");
            existing.setDepartment("内科");
            existing.setDifficulty(2);
            existing.setPatientProfile("{\"age\":30}");
            existing.setHiddenDisease("流感");
            existing.setStandardPathJson("{}");
            existing.setIsPublic(false);
            existing.setVersion(1);
            existing.setStatus(0);
            existing.setAdminAuditStatus(0);
            when(caseMapper.selectById(1L)).thenReturn(existing);

            CasePreviewVO vo = service.preview(1L);

            assertThat(vo).isNotNull();
            assertThat(vo.getId()).isEqualTo(1L);
            assertThat(vo.getTitle()).isEqualTo("预览病例");
            assertThat(vo.getHiddenDisease()).isEqualTo("流感");
        }
    }
}
