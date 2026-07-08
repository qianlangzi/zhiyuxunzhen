package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDate;

/**
 * 每日一例排期表（PRD 8.10）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("daily_case_schedule")
public class DailyCaseSchedule extends BaseEntity {

    private Long caseId;

    private LocalDate publishDate;

    private String targetGrade;

    /** 0草稿 1已排期 2已发布 */
    private Integer status;

    private Long createdBy;
}
