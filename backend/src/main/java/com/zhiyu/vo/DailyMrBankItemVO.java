package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * 每日病历 · 题库列表项 VO（往期每日一例，LeetCode 题库风格）
 */
@Data
@Builder
public class DailyMrBankItemVO {

    private Long scheduleId;

    private String caseTitle;

    private String department;

    private Integer difficulty;

    private LocalDate publishDate;

    /** 我是否已提交过 */
    private Boolean done;

    /** 我的最新得分（未做/未批出为 null） */
    private BigDecimal myScore;

    /** 我提交的版本数 */
    private Integer myVersions;
}
