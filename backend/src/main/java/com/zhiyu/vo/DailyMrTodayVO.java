package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * 每日病历 · 今日卡 VO（LeetCode 每日一题风格）
 */
@Data
@Builder
public class DailyMrTodayVO {

    private Long scheduleId;

    private Long caseId;

    private String caseTitle;

    private String department;

    /** 难度：1入门 2进阶 3挑战 */
    private Integer difficulty;

    private LocalDate publishDate;

    /** 患者画像 */
    private String patientProfile;

    /** 关键检查结果 */
    private String keyFindings;

    /** 系统标签（呼吸/循环…），可空 */
    private String systemTag;

    /** 连续打卡天数 */
    private Integer streak;

    /** 今日是否已提交过病历 */
    private Boolean doneToday;

    /** 我对该期最新一次病历记录（可为 null） */
    private MyRecord myRecord;

    @Data
    @Builder
    public static class MyRecord {
        private Long recordId;
        private Integer version;
        private BigDecimal totalScore;
        /** 0草稿 1已提交待批 2已批阅 */
        private Integer status;
        /** AI 置信度，教师复核前展示用 */
        private BigDecimal aiConfidence;
    }
}
