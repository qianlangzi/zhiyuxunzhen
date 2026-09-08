package com.zhiyu.service.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 教师修改已发布作业的设置（学习通式：延期、补交窗口、公布策略等）
 * 字段为 null 表示不修改，便于前端按需提交。
 */
@Data
public class AssignmentSettingsDTO {

    /** 截止时间（延期/提前） */
    private LocalDateTime deadline;

    /** 开始时间（定时发布），为空表示立即发布 */
    private LocalDateTime startTime;

    /** 是否允许迟交 */
    private Boolean allowLateSubmit;

    /** 补交截止时间 */
    private LocalDateTime lateDeadline;

    /** 作业总分 */
    private BigDecimal totalScore;

    /** 成绩公布方式：IMMEDIATE / AFTER_DEADLINE / MANUAL */
    private String scorePublishMode;

    /** 答案与解析公布方式：IMMEDIATE / AFTER_DEADLINE / MANUAL */
    private String answerPublishMode;

    /** 题目乱序 */
    private Boolean shuffleQuestions;

    /** 允许提交次数 */
    private Integer maxAttempts;

    /** 抄袭检测 */
    private Boolean plagiarismCheck;
}
