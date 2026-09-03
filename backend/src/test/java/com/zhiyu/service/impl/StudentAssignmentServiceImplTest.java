package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.FormatCheckService;
import com.zhiyu.service.dto.SubmitRecordDTO;
import com.zhiyu.vo.FormatCheckResultVO;
import com.zhiyu.vo.StudentAssignmentVO;
import com.zhiyu.vo.SubmitRecordResultVO;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.MockedStatic;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * 学生作业服务 — 单元测试（纯 Mockito + mockStatic UserContext）
 */
@DisplayName("学生作业服务 StudentAssignmentServiceImpl")
@ExtendWith(MockitoExtension.class)
class StudentAssignmentServiceImplTest {

    @Mock
    private AssignmentInstanceMapper instanceMapper;

    @Mock
    private AssignmentMapper assignmentMapper;

    @Mock
    private AssignmentItemMapper itemMapper;

    @Mock
    private SpCaseConfigMapper caseMapper;

    @Mock
    private FormatCheckService formatCheckService;

    @Mock
    private ObjectMapper objectMapper;

    @InjectMocks
    private StudentAssignmentServiceImpl service;

    private SubmitRecordDTO buildSubmitDTO() {
        SubmitRecordDTO dto = new SubmitRecordDTO();
        dto.setMedicalRecordText("主诉：头痛三天\n现病史：患者三天前出现头痛\n既往史：高血压病史五年\n"
                + "过敏史：青霉素\n体格检查：神志清楚\n辅助检查：血常规正常\n初步诊断：偏头痛");
        return dto;
    }

    private AssignmentInstance buildInstance(Long studentId, Integer status) {
        AssignmentInstance inst = new AssignmentInstance();
        inst.setId(1L);
        inst.setAssignmentId(10L);
        inst.setStudentId(studentId);
        inst.setCaseId(20L);
        inst.setStatus(status);
        return inst;
    }

    private Assignment buildAssignment(LocalDateTime deadline, Boolean allowLate) {
        Assignment a = new Assignment();
        a.setId(10L);
        a.setTitle("期中作业");
        a.setDeadline(deadline);
        a.setAllowLateSubmit(allowLate);
        a.setFormatRuleJson("{}");
        return a;
    }

    // ==================== submitRecord ====================

    @Test
    @DisplayName("submitRecord（非本人实例）→ BizException(FORBIDDEN)")
    void should_throw_forbidden_when_submit_by_non_owner() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            // 实例属于学生 200，当前用户是 100
            when(instanceMapper.selectById(1L)).thenReturn(buildInstance(200L, 0));

            assertThatThrownBy(() -> service.submitRecord(1L, null, buildSubmitDTO()))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.FORBIDDEN.getCode()));

            verify(assignmentMapper, never()).selectById(any());
            verify(formatCheckService, never()).check(anyString(), anyString());
        }
    }

    @Test
    @DisplayName("submitRecord（重复提交 status=3）→ BizException(DUPLICATE_SUBMIT)")
    void should_throw_duplicate_when_status_is_3() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(instanceMapper.selectById(1L)).thenReturn(buildInstance(100L, 3)); // AI批阅中

            assertThatThrownBy(() -> service.submitRecord(1L, null, buildSubmitDTO()))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.DUPLICATE_SUBMIT.getCode()));

            verify(assignmentMapper, never()).selectById(any());
        }
    }

    @Test
    @DisplayName("submitRecord（重复提交 status=5）→ BizException(DUPLICATE_SUBMIT)")
    void should_throw_duplicate_when_status_is_5() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(instanceMapper.selectById(1L)).thenReturn(buildInstance(100L, 5)); // 已完成

            assertThatThrownBy(() -> service.submitRecord(1L, null, buildSubmitDTO()))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.DUPLICATE_SUBMIT.getCode()));
        }
    }

    @Test
    @DisplayName("submitRecord（已截止且不允许迟交）→ BizException(ASSIGNMENT_DEADLINE_PASSED)")
    void should_throw_when_deadline_passed_and_no_late_submit() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(instanceMapper.selectById(1L)).thenReturn(buildInstance(100L, 0));
            // 截止时间是昨天，不允许迟交
            when(assignmentMapper.selectById(10L))
                    .thenReturn(buildAssignment(LocalDateTime.now().minusDays(1), false));

            assertThatThrownBy(() -> service.submitRecord(1L, null, buildSubmitDTO()))
                    .isInstanceOf(BizException.class)
                    .satisfies(ex -> assertThat(((BizException) ex).getCode())
                            .isEqualTo(ResultCode.ASSIGNMENT_DEADLINE_PASSED.getCode()));

            verify(formatCheckService, never()).check(anyString(), anyString());
        }
    }

    @Test
    @DisplayName("submitRecord（格式校验通过）→ status=3（AI批阅中）")
    void should_set_status_3_when_format_check_passed() throws JsonProcessingException {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(instanceMapper.selectById(1L)).thenReturn(buildInstance(100L, 0));
            when(assignmentMapper.selectById(10L))
                    .thenReturn(buildAssignment(LocalDateTime.now().plusDays(1), false));

            FormatCheckResultVO checkResult = FormatCheckResultVO.builder()
                    .passed(true)
                    .errors(List.of())
                    .checkedAt(LocalDateTime.now())
                    .build();
            when(formatCheckService.check(anyString(), anyString())).thenReturn(checkResult);
            when(objectMapper.writeValueAsString(any())).thenReturn("{\"passed\":true}");
            when(instanceMapper.updateById(any())).thenReturn(1);

            SubmitRecordResultVO result = service.submitRecord(1L, null, buildSubmitDTO());

            assertThat(result).isNotNull();
            assertThat(result.getStatus()).isEqualTo(3);
            assertThat(result.getPassed()).isTrue();
            assertThat(result.getInstanceId()).isEqualTo(1L);

            // 验证 instance 被更新为 status=3
            ArgumentCaptor<AssignmentInstance> captor = ArgumentCaptor.forClass(AssignmentInstance.class);
            verify(instanceMapper).updateById(captor.capture());
            assertThat(captor.getValue().getStatus()).isEqualTo(3);
        }
    }

    @Test
    @DisplayName("submitRecord（格式校验失败）→ status=2（格式打回）")
    void should_set_status_2_when_format_check_failed() throws JsonProcessingException {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            when(instanceMapper.selectById(1L)).thenReturn(buildInstance(100L, 0));
            when(assignmentMapper.selectById(10L))
                    .thenReturn(buildAssignment(LocalDateTime.now().plusDays(1), false));

            FormatCheckResultVO checkResult = FormatCheckResultVO.builder()
                    .passed(false)
                    .errors(List.of("缺少必填段落：主诉"))
                    .checkedAt(LocalDateTime.now())
                    .build();
            when(formatCheckService.check(anyString(), anyString())).thenReturn(checkResult);
            when(objectMapper.writeValueAsString(any())).thenReturn("{\"passed\":false}");
            when(instanceMapper.updateById(any())).thenReturn(1);

            SubmitRecordResultVO result = service.submitRecord(1L, null, buildSubmitDTO());

            assertThat(result).isNotNull();
            assertThat(result.getStatus()).isEqualTo(2);
            assertThat(result.getPassed()).isFalse();

            ArgumentCaptor<AssignmentInstance> captor = ArgumentCaptor.forClass(AssignmentInstance.class);
            verify(instanceMapper).updateById(captor.capture());
            assertThat(captor.getValue().getStatus()).isEqualTo(2);
        }
    }

    // ==================== myAssignments ====================

    @Test
    @DisplayName("myAssignments → 批量补全作业标题、病例标题（避免 N+1 查询）")
    void should_batch_fill_titles_in_my_assignments() {
        try (MockedStatic<UserContext> mocked = Mockito.mockStatic(UserContext.class)) {
            mocked.when(UserContext::requireUserId).thenReturn(100L);

            AssignmentInstance inst1 = new AssignmentInstance();
            inst1.setId(1L);
            inst1.setAssignmentId(10L);
            inst1.setCaseId(20L);
            inst1.setStatus(0);

            AssignmentInstance inst2 = new AssignmentInstance();
            inst2.setId(2L);
            inst2.setAssignmentId(11L);
            inst2.setCaseId(21L);
            inst2.setStatus(3);

            when(instanceMapper.selectPage(any(Page.class), any())).thenAnswer(inv -> {
                Page<AssignmentInstance> p = inv.getArgument(0);
                p.setRecords(List.of(inst1, inst2));
                p.setTotal(2);
                return p;
            });

            Assignment a1 = new Assignment();
            a1.setId(10L);
            a1.setTitle("第一次作业");
            a1.setDeadline(LocalDateTime.now().plusDays(3));

            Assignment a2 = new Assignment();
            a2.setId(11L);
            a2.setTitle("第二次作业");
            a2.setDeadline(LocalDateTime.now().minusDays(1));

            when(assignmentMapper.selectList(any())).thenReturn(List.of(a1, a2));

            SpCaseConfig c1 = new SpCaseConfig();
            c1.setId(20L);
            c1.setTitle("感冒病例");

            SpCaseConfig c2 = new SpCaseConfig();
            c2.setId(21L);
            c2.setTitle("骨折病例");

            when(caseMapper.selectList(any())).thenReturn(List.of(c1, c2));

            // 组合包任务项（loadItemSummary 依赖）：本场景无任务项，返回空列表
            when(itemMapper.selectList(any())).thenReturn(List.of());

            PageResult<StudentAssignmentVO> result = service.myAssignments(1, 10);

            assertThat(result).isNotNull();
            assertThat(result.getTotal()).isEqualTo(2);
            assertThat(result.getList()).hasSize(2);

            // 验证批量补全的标题
            StudentAssignmentVO vo1 = result.getList().get(0);
            assertThat(vo1.getInstanceId()).isEqualTo(1L);
            assertThat(vo1.getAssignmentTitle()).isEqualTo("第一次作业");
            assertThat(vo1.getCaseTitle()).isEqualTo("感冒病例");
            assertThat(vo1.getStatus()).isEqualTo(0);

            StudentAssignmentVO vo2 = result.getList().get(1);
            assertThat(vo2.getInstanceId()).isEqualTo(2L);
            assertThat(vo2.getAssignmentTitle()).isEqualTo("第二次作业");
            assertThat(vo2.getCaseTitle()).isEqualTo("骨折病例");
            assertThat(vo2.getStatus()).isEqualTo(3);

            // 验证批量查询（而非逐条 N+1）
            verify(assignmentMapper, times(1)).selectList(any());
            verify(caseMapper, times(1)).selectList(any());
        }
    }
}
