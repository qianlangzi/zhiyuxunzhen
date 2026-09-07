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

    private String question;

    private String optionsJson;

    private String standardAnswer;

    private String answerExplanation;

    private String textbookRef;

    /** 病例摘要：患者画像+关键检查，供书写与AI批阅参考（V43） */
    private String caseSummary;

    /** 难度：1入门 2进阶 3挑战（V43，空则取病例难度） */
    private Integer difficulty;

    /** 系统/科室标签，如 呼吸/循环/消化（V43） */
    private String systemTag;

    /** 作答模式：0开放作答(旧) 1大病历九段书写（V43） */
    private Integer writingMode;

    /** 参考病历（教师/教研提供），学生提交后可见（V43） */
    private String referenceRecord;

    /** 0草稿 1已排期 2已发布 */
    private Integer status;

    private Long createdBy;
}
