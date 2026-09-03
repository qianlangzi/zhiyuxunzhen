package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

/**
 * 管理员排期每日一例请求（PRD 4.16 / 8.10）
 */
@Data
public class DailyCaseScheduleDTO {

    @NotNull(message = "病例ID不能为空")
    private Long caseId;

    @NotNull(message = "推送日期不能为空")
    private LocalDate publishDate;

    /** 目标年级（可空，空则全员） */
    private String targetGrade;
}
