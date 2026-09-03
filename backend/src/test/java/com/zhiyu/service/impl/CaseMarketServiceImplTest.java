package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.vo.CaseMarketListVO;
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
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * 病例广场服务 — 单元测试（纯 Mockito + mockStatic UserContext）
 */
@DisplayName("病例广场服务 CaseMarketServiceImpl")
@ExtendWith(MockitoExtension.class)
class CaseMarketServiceImplTest {

    @Mock
    private SpCaseConfigMapper caseMapper;

    @Mock
    private SysUserMapper userMapper;

    @InjectMocks
    private CaseMarketServiceImpl service;

    private SpCaseConfig buildPublicCase() {
        SpCaseConfig c = new SpCaseConfig();
        c.setId(1L);
        c.setCreatorId(50L);
        c.setTitle("广场公开病例");
        c.setDepartment("内科");
        c.setDifficulty(2);
        c.setIsPublic(true);
        c.setAdminAuditStatus(2);
        c.setStatus(1);
        c.setReferenceCount(5);
        c.setRatingAvg(new BigDecimal("4.5"));
        c.setKnowledgeTags("[\"发热\",\"咳嗽\"]");
        return c;
    }

    // ==================== list ====================

    @Test
    @DisplayName("list → 返回公开且审核通过的病例，批量补全创建者姓名")
    void should_return_public_audited_cases_with_creator_names() {
        SpCaseConfig record = buildPublicCase();

        when(caseMapper.selectPage(any(Page.class), any())).thenAnswer(inv -> {
            Page<SpCaseConfig> p = inv.getArgument(0);
            p.setRecords(List.of(record));
            p.setTotal(1);
            return p;
        });

        SysUser creator = new SysUser();
        creator.setId(50L);
        creator.setRealName("王医生");
        when(userMapper.selectList(any())).thenReturn(List.of(creator));

        PageResult<CaseMarketListVO> result = service.list(1, 10, null, null, null, null, null);

        assertThat(result).isNotNull();
        assertThat(result.getTotal()).isEqualTo(1);
        assertThat(result.getList()).hasSize(1);

        CaseMarketListVO vo = result.getList().get(0);
        assertThat(vo.getId()).isEqualTo(1L);
        assertThat(vo.getTitle()).isEqualTo("广场公开病例");
        assertThat(vo.getDepartment()).isEqualTo("内科");
        assertThat(vo.getCreatorName()).isEqualTo("王医生");
        assertThat(vo.getRatingAvg()).isEqualByComparingTo(new BigDecimal("4.5"));
        assertThat(vo.getReferenceCount()).isEqualTo(5);
    }

    @Test
    @DisplayName("list 多种排序（rating/reference/createdAt/default）→ 均不抛异常")
    void should_support_multiple_sort_options() {
        when(caseMapper.selectPage(any(Page.class), any())).thenAnswer(inv -> {
            Page<SpCaseConfig> p = inv.getArgument(0);
            p.setRecords(List.of());
            p.setTotal(0);
            return p;
        });

        // 不同排序方式均应正常执行
        service.list(1, 10, null, null, null, "rating", "desc");
        service.list(1, 10, null, null, null, "reference", "asc");
        service.list(1, 10, null, null, null, "createdAt", "desc");
        service.list(1, 10, null, null, null, null, null); // 默认排序

        verify(caseMapper, times(4)).selectPage(any(Page.class), any());
    }

    @Test
    @DisplayName("list 带科室和难度过滤 → 正常返回")
    void should_filter_by_department_and_difficulty() {
        when(caseMapper.selectPage(any(Page.class), any())).thenAnswer(inv -> {
            Page<SpCaseConfig> p = inv.getArgument(0);
            p.setRecords(List.of());
            p.setTotal(0);
            return p;
        });

        PageResult<CaseMarketListVO> result = service.list(1, 10, "内科", 2, null, null, null);

        assertThat(result).isNotNull();
        verify(caseMapper, times(1)).selectPage(any(Page.class), any());
    }

    @Test
    @DisplayName("list 带关键字搜索 → 正常返回（服务端模糊匹配标题/画像/知识点）")
    void should_filter_by_keyword() {
        when(caseMapper.selectPage(any(Page.class), any())).thenAnswer(inv -> {
            Page<SpCaseConfig> p = inv.getArgument(0);
            p.setRecords(List.of());
            p.setTotal(0);
            return p;
        });

        PageResult<CaseMarketListVO> result = service.list(1, 10, null, null, "心肌梗死", null, null);

        assertThat(result).isNotNull();
        verify(caseMapper, times(1)).selectPage(any(Page.class), any());
    }

    @Test
    @DisplayName("departments → 返回去重排序后的科室列表")
    void should_return_distinct_departments() {
        SpCaseConfig c1 = buildPublicCase(); // 内科
        SpCaseConfig c2 = buildPublicCase();
        c2.setId(2L);
        c2.setDepartment("外科");
        SpCaseConfig c3 = buildPublicCase();
        c3.setId(3L);
        c3.setDepartment("内科"); // 与 c1 重复，应去重
        when(caseMapper.selectList(any())).thenReturn(List.of(c1, c2, c3));

        List<String> departments = service.departments();

        assertThat(departments).containsExactly("内科", "外科");
    }

    // ==================== quote ====================

    @Test
    @DisplayName("quote（非教师）→ BizException(FORBIDDEN)")
    void should_throw_forbidden_when_quote_by_non_teacher() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            // 模拟 requireRole(1) 抛出 FORBIDDEN
            mocked.when(() -> UserContext.requireRole(1))
                    .thenThrow(new BizException(ResultCode.FORBIDDEN));

            assertThatThrownBy(() -> service.quote(1L))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.FORBIDDEN.getCode()));

            verify(caseMapper, never()).selectById(any());
        }
    }

    @Test
    @DisplayName("quote（病例不存在）→ BizException(CASE_NOT_FOUND)")
    void should_throw_when_quote_nonexistent_case() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(caseMapper.selectById(1L)).thenReturn(null);

            assertThatThrownBy(() -> service.quote(1L))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.CASE_NOT_FOUND.getCode()));
        }
    }

    @Test
    @DisplayName("quote（未公开）→ BizException（错误码 2108）")
    void should_throw_when_case_not_public() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            SpCaseConfig src = buildPublicCase();
            src.setIsPublic(false); // 未公开
            when(caseMapper.selectById(1L)).thenReturn(src);

            assertThatThrownBy(() -> service.quote(1L))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode()).isEqualTo(2108));
        }
    }

    @Test
    @DisplayName("quote（未通过审核）→ BizException（错误码 2108）")
    void should_throw_when_case_not_audited() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            SpCaseConfig src = buildPublicCase();
            src.setAdminAuditStatus(0); // 未审核
            when(caseMapper.selectById(1L)).thenReturn(src);

            assertThatThrownBy(() -> service.quote(1L))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode()).isEqualTo(2108));
        }
    }

    @Test
    @DisplayName("quote 成功 → 校验副本字段、原病例引用量+1、返回新 ID")
    void should_create_copy_and_increment_reference_when_quote_success() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            SpCaseConfig src = buildPublicCase();
            src.setReferenceCount(5);
            when(caseMapper.selectById(1L)).thenReturn(src);

            // 模拟 insert 时回填自增 ID
            when(caseMapper.insert(any(SpCaseConfig.class))).thenAnswer(inv -> {
                SpCaseConfig c = inv.getArgument(0);
                c.setId(999L);
                return 1;
            });
            when(caseMapper.incrementReferenceCount(1L)).thenReturn(1);

            Long newId = service.quote(1L);

            assertThat(newId).isEqualTo(999L);

            // 校验副本字段
            ArgumentCaptor<SpCaseConfig> insertCaptor = ArgumentCaptor.forClass(SpCaseConfig.class);
            verify(caseMapper).insert(insertCaptor.capture());
            SpCaseConfig copy = insertCaptor.getValue();
            assertThat(copy.getCreatorId()).isEqualTo(100L);
            assertThat(copy.getSourceCaseId()).isEqualTo(1L);
            assertThat(copy.getIsPublic()).isFalse();
            assertThat(copy.getVersion()).isEqualTo(1);
            assertThat(copy.getStatus()).isEqualTo(0);
            assertThat(copy.getAdminAuditStatus()).isEqualTo(0);
            assertThat(copy.getReferenceCount()).isEqualTo(0);
            assertThat(copy.getRatingAvg()).isEqualByComparingTo(BigDecimal.ZERO);
            assertThat(copy.getTitle()).isEqualTo("广场公开病例");

            // 校验原病例引用量原子自增（SQL incrementReferenceCount）
            verify(caseMapper).incrementReferenceCount(1L);
        }
    }
}
