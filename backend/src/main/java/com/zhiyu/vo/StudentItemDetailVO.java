package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 学生作业-任务项详情（详情页用，含各类型内容）
 */
@Data
@Builder
public class StudentItemDetailVO {
    private Long itemId;
    /** 任务项进度ID（提交/跳转问诊用） */
    private Long progressId;
    /** CASE / PRACTICE / READING */
    private String itemType;
    private String title;
    /** 0未开始 1进行中 2已提交/格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private BigDecimal score;
    private LocalDateTime submitTime;
    private LocalDateTime completedAt;

    /** CASE:病例问诊 */
    private Long caseId;
    private String caseTitle;
    private String department;
    private String patientProfile;
    private String hiddenDisease;
    private Long sessionId;
    private String medicalRecordText;
    private String formatCheckResult;

    /** PRACTICE:练习题目列表（不含答案，交卷后端判分） */
    private List<StudentQuestionVO> questions;

    /** READING:阅读任务 */
    private Long textbookId;
    private String textbookTitle;
    private String textbookFileUrl;
    private String readingScope;
}
