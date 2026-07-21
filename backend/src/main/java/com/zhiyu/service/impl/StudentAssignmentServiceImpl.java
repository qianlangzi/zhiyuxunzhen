package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.FormatCheckService;
import com.zhiyu.service.StudentAssignmentService;
import com.zhiyu.service.dto.SubmitRecordDTO;
import com.zhiyu.vo.FormatCheckResultVO;
import com.zhiyu.vo.StudentAssignmentVO;
import com.zhiyu.vo.SubmitRecordResultVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 学生作业服务实现（PRD 4.4 / 5.3 / 9.1）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentAssignmentServiceImpl implements StudentAssignmentService {

    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentMapper assignmentMapper;
    private final SpCaseConfigMapper caseMapper;
    private final FormatCheckService formatCheckService;
    private final ObjectMapper objectMapper;
    private final AiPlatformClient aiPlatformClient;

    @Override
    public PageResult<StudentAssignmentVO> myAssignments(Integer pageNum, Integer pageSize) {
        Long studentId = UserContext.requireUserId();
        Page<AssignmentInstance> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<AssignmentInstance> wrapper = new LambdaQueryWrapper<AssignmentInstance>()
                .eq(AssignmentInstance::getStudentId, studentId)
                .orderByDesc(AssignmentInstance::getCreatedAt);
        instanceMapper.selectPage(page, wrapper);

        List<AssignmentInstance> records = page.getRecords();
        // 批量补全作业标题、病例标题、截止时间
        List<Long> assignmentIds = records.stream()
                .map(AssignmentInstance::getAssignmentId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        List<Long> caseIds = records.stream()
                .map(AssignmentInstance::getCaseId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, Assignment> aMap = new HashMap<>();
        if (!assignmentIds.isEmpty()) {
            for (Assignment a : assignmentMapper.selectList(
                    new LambdaQueryWrapper<Assignment>().in(Assignment::getId, assignmentIds))) {
                aMap.put(a.getId(), a);
            }
        }
        Map<Long, SpCaseConfig> cMap = new HashMap<>();
        if (!caseIds.isEmpty()) {
            for (SpCaseConfig c : caseMapper.selectList(
                    new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, caseIds))) {
                cMap.put(c.getId(), c);
            }
        }

        List<StudentAssignmentVO> list = records.stream().map(inst -> {
            Assignment a = aMap.get(inst.getAssignmentId());
            SpCaseConfig c = cMap.get(inst.getCaseId());
            return StudentAssignmentVO.builder()
                    .instanceId(inst.getId())
                    .assignmentId(inst.getAssignmentId())
                    .assignmentTitle(a == null ? null : a.getTitle())
                    .caseId(inst.getCaseId())
                    .caseTitle(c == null ? null : c.getTitle())
                    .deadline(a == null ? null : a.getDeadline())
                    .status(inst.getStatus())
                    .build();
        }).collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public SubmitRecordResultVO submitRecord(Long instanceId, SubmitRecordDTO req) {
        Long studentId = UserContext.requireUserId();
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
        }
        if (!studentId.equals(inst.getStudentId())) {
            throw new BizException(ResultCode.FORBIDDEN);
        }

        int status = inst.getStatus() == null ? 0 : inst.getStatus();
        // 已进入批阅/完成流程，禁止重复提交
        if (status == 3 || status == 4 || status == 5) {
            throw new BizException(ResultCode.DUPLICATE_SUBMIT);
        }

        Assignment a = assignmentMapper.selectById(inst.getAssignmentId());
        if (a == null) {
            throw new BizException(ResultCode.ASSIGNMENT_NOT_FOUND);
        }

        // 截止时间校验
        LocalDateTime now = LocalDateTime.now();
        boolean allowLate = a.getAllowLateSubmit() != null && a.getAllowLateSubmit();
        if (a.getDeadline() != null && now.isAfter(a.getDeadline()) && !allowLate) {
            throw new BizException(ResultCode.ASSIGNMENT_DEADLINE_PASSED);
        }

        // 格式盾牌校验
        FormatCheckResultVO checkResult = formatCheckService.check(req.getMedicalRecordText(), a.getFormatRuleJson());

        inst.setMedicalRecordText(req.getMedicalRecordText());
        inst.setSubmitTime(now);
        inst.setFormatCheckResult(toJson(checkResult));
        if (Boolean.TRUE.equals(checkResult.getPassed())) {
            inst.setStatus(3); // AI批阅中
        } else {
            inst.setStatus(2); // 格式打回
        }
        instanceMapper.updateById(inst);

        log.info("学生{}提交作业实例{}，格式校验{}，状态={}", studentId, instanceId, checkResult.getPassed(), inst.getStatus());

        // 格式校验通过：事务提交后异步触发 AI 批阅（PRD 5.3 第 4-5 步）
        // 失败不回滚学生提交事务，AI 批阅结果由 FastAPI 通过 /api/internal/review/callback 回写
        if (Boolean.TRUE.equals(checkResult.getPassed())) {
            final Long instanceIdRef = instanceId;
            final String medicalText = req.getMedicalRecordText();
            if (TransactionSynchronizationManager.isSynchronizationActive()) {
                TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                    @Override
                    public void afterCommit() {
                        triggerAiReview(instanceIdRef, medicalText);
                    }
                });
            } else {
                // 单元测试或非代理调用没有事务同步上下文时，直接触发，避免注册同步抛异常。
                triggerAiReview(instanceIdRef, medicalText);
            }
        }

        return SubmitRecordResultVO.builder()
                .instanceId(instanceId)
                .status(inst.getStatus())
                .passed(checkResult.getPassed())
                .formatCheckResult(checkResult)
                .build();
    }

    /**
     * 异步触发 AI 批阅（PRD 5.3 / 9.3）
     * 由 aiTaskExecutor 线程池执行，异常仅记录日志不抛出
     */
    @Async("aiTaskExecutor")
    public void triggerAiReview(Long instanceId, String medicalRecordText) {
        try {
            log.info("触发AI批阅: instanceId={}", instanceId);
            aiPlatformClient.reviewMedicalRecord(instanceId, medicalRecordText);
        } catch (Exception e) {
            // AI 中台不可用时仅记录日志，状态仍为 3（AI批阅中），后续可由运维触发重试
            log.error("AI批阅触发失败: instanceId={} error={}", instanceId, e.getMessage(), e);
        }
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            log.warn("JSON序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
