package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;

/**
 * 每日一例展示 VO（PRD 4.10）
 */
@Data
@Builder
public class DailyCaseVO {

    private Long scheduleId;

    private Long caseId;

    private String caseTitle;

    private String department;

    private Integer difficulty;

    private LocalDate publishDate;

    private String targetGrade;

    private String question;

    private String optionsJson;

    private String textbookRef;

    /** 0草稿 1已排期 2已发布 */
    private Integer status;
}
