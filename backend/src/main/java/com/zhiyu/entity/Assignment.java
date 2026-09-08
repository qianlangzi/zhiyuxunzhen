package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 作业表（PRD 8.3）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("assignment")
public class Assignment extends BaseEntity {

    private Long teacherId;

    private Long caseId;

    private String title;

    private String description;

    private Boolean requireMedicalRecord;

    /** 格式盾牌规则 JSON */
    private String formatRuleJson;

    /** 防作弊变量配置 JSON */
    private String antiCheatVariables;

    private LocalDateTime deadline;

    /** 开始时间（定时发布），为空表示立即发布 */
    private LocalDateTime startTime;

    /** 补交截止时间（allowLateSubmit=true 时生效） */
    private LocalDateTime lateDeadline;

    /** 作业总分 */
    private BigDecimal totalScore;

    /** 成绩公布方式：IMMEDIATE 提交即公布 / AFTER_DEADLINE 截止后公布 / MANUAL 教师手动公布 */
    private String scorePublishMode;

    /** 答案与解析公布方式：IMMEDIATE / AFTER_DEADLINE / MANUAL */
    private String answerPublishMode;

    /** 题目乱序 */
    private Boolean shuffleQuestions;

    /** 允许提交次数（最小 1） */
    private Integer maxAttempts;

    /** 抄袭检测开关 */
    private Boolean plagiarismCheck;

    private Boolean allowLateSubmit;

    /** 0草稿 1进行中 2已截止 */

    @TableField("`status`")
    private Integer status;

    @TableLogic
    @TableField(value = "is_deleted")
    private Integer isDeleted;
}
