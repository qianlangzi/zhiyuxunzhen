package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.DailyCaseSchedule;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.DailyCaseScheduleMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.DailyCaseService;
import com.zhiyu.service.dto.DailyCaseAnswerDTO;
import com.zhiyu.service.dto.DailyCaseScheduleDTO;
import com.zhiyu.vo.DailyCaseVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * 每日一例服务实现（PRD 4.10 / 4.16 / 8.10）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DailyCaseServiceImpl implements DailyCaseService {

    private final DailyCaseScheduleMapper scheduleMapper;
    private final SpCaseConfigMapper caseMapper;
    private final AiPlatformClient aiPlatformClient;
    private final AuditLogService auditLogService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long schedule(DailyCaseScheduleDTO dto) {
        Long adminId = UserContext.requireUserId();

        // 校验病例存在
        SpCaseConfig c = caseMapper.selectById(dto.getCaseId());
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }

        // 同一日期只能有一个排期（uk_date 唯一索引）
        Long exists = scheduleMapper.selectCount(
                new LambdaQueryWrapper<DailyCaseSchedule>()
                        .eq(DailyCaseSchedule::getPublishDate, dto.getPublishDate()));
        if (exists != null && exists > 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "该日期已有排期，请先删除或更换日期");
        }

        DailyCaseSchedule schedule = new DailyCaseSchedule();
        schedule.setCaseId(dto.getCaseId());
        schedule.setPublishDate(dto.getPublishDate());
        schedule.setTargetGrade(dto.getTargetGrade());
        schedule.setStatus(2); // 直接发布
        schedule.setCreatedBy(adminId);
        scheduleMapper.insert(schedule);

        auditLogService.record("daily_case_schedule", "daily_case_schedule", schedule.getId(),
                null, "{\"caseId\":" + dto.getCaseId() + ",\"date\":\"" + dto.getPublishDate() + "\"}");
        log.info("管理员{}排期每日一例: scheduleId={} date={}", adminId, schedule.getId(), dto.getPublishDate());
        return schedule.getId();
    }

    @Override
    public PageResult<DailyCaseVO> scheduleList(Integer pageNum, Integer pageSize) {
        Page<DailyCaseSchedule> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<DailyCaseSchedule> wrapper = new LambdaQueryWrapper<DailyCaseSchedule>()
                .orderByDesc(DailyCaseSchedule::getPublishDate);
        scheduleMapper.selectPage(page, wrapper);

        var list = page.getRecords().stream().map(s -> {
            SpCaseConfig c = s.getCaseId() == null ? null : caseMapper.selectById(s.getCaseId());
            return DailyCaseVO.builder()
                    .scheduleId(s.getId())
                    .caseId(s.getCaseId())
                    .caseTitle(c == null ? null : c.getTitle())
                    .department(c == null ? null : c.getDepartment())
                    .difficulty(c == null ? null : c.getDifficulty())
                    .publishDate(s.getPublishDate())
                    .targetGrade(s.getTargetGrade())
                    .status(s.getStatus())
                    .build();
        }).toList();
        return PageResult.of(page, list);
    }

    @Override
    public DailyCaseVO today() {
        LocalDate today = LocalDate.now();
        DailyCaseSchedule s = scheduleMapper.selectOne(
                new LambdaQueryWrapper<DailyCaseSchedule>()
                        .eq(DailyCaseSchedule::getPublishDate, today)
                        .eq(DailyCaseSchedule::getStatus, 2)
                        .last("LIMIT 1"));
        if (s == null) {
            return null;
        }
        SpCaseConfig c = caseMapper.selectById(s.getCaseId());
        return DailyCaseVO.builder()
                .scheduleId(s.getId())
                .caseId(s.getCaseId())
                .caseTitle(c == null ? null : c.getTitle())
                .department(c == null ? null : c.getDepartment())
                .difficulty(c == null ? null : c.getDifficulty())
                .publishDate(s.getPublishDate())
                .targetGrade(s.getTargetGrade())
                .status(s.getStatus())
                .build();
    }

    @Override
    public String submitAnswer(DailyCaseAnswerDTO dto) {
        Long studentId = UserContext.requireUserId();
        DailyCaseSchedule s = scheduleMapper.selectById(dto.getScheduleId());
        if (s == null) {
            throw new BizException(ResultCode.NOT_FOUND, "排期不存在");
        }
        // 调用 AI 中台评估（PRD 9.3 / 4.10.2）
        // AI 不可用时由 AiPlatformClient 抛 BizException，前端展示降级提示
        return aiPlatformClient.evaluateDailyCase(studentId, s.getCaseId(), dto.getAnswer());
    }
}
