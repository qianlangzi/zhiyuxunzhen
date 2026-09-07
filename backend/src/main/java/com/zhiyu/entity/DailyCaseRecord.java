package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 每日病历记录表（V43）：支持同一排期多次提交 / 版本迭代。
 * status: 0草稿 1已提交待批 2已批阅
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("daily_case_record")
public class DailyCaseRecord extends BaseEntity {

    private Long scheduleId;

    private Long studentId;

    /** 第几次提交（同一排期可反复修订） */
    private Integer version;

    /** 0草稿 1已提交待批 2已批阅 */
    private Integer status;

    /** AI 批阅总分（百分制） */
    private BigDecimal totalScore;

    /** AI 批阅置信度 0-1，>=0.85 教师端可免复核 */
    private BigDecimal aiConfidence;

    /** 九段内容 JSON: {"chief_complaint":"...","history_present":"...",...} */
    private String contentJson;

    /** AI 批阅结果 JSON（九段分 + 缺陷清单 + 评语） */
    private String reviewJson;

    /** 教师复核后的最终分（覆盖 AI 分） */
    private BigDecimal teacherScore;

    /** 教师复核评语 */
    private String teacherComment;

    /** 复核教师ID */
    private Long reviewedBy;

    private LocalDateTime submittedAt;
}
