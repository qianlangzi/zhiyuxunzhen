package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 学生作业任务项进度表（组合任务包）
 * 每个学生 × 每个任务项 一条进度;病例问诊的会话/病历/AI批阅挂在这里。
 * status: 0未开始 1进行中 2已提交/格式打回 3AI批阅中 4待复核 5已完成
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("assignment_item_progress")
public class AssignmentItemProgress extends BaseEntity {

    private Long instanceId;

    private Long itemId;

    private Long studentId;

    /** CASE:病例ID */
    private Long caseId;

    /** CASE:该学生防作弊变量快照 JSON */
    private String variableSnapshotJson;

    /** CASE:问诊会话ID */
    private Long sessionId;

    /** CASE:大病历正文 */
    private String medicalRecordText;

    /** CASE:格式盾牌校验结果 JSON */
    private String formatCheckResult;

    /** PRACTICE:学生答案 JSON {"qid":{"answer":"...","correct":true}} */
    private String answersJson;

    /** 得分(练习自动判分/病例AI评分/教师复核) */
    private BigDecimal score;

    /** 完成时间(阅读标记/练习交卷) */
    private LocalDateTime completedAt;

    private LocalDateTime submitTime;

    private String aiErrorMessage;

    private Integer aiRetryCount;

    private LocalDateTime aiLastAttemptAt;

    /** 0未开始 1进行中 2已提交/格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;

    @TableLogic
    private Integer isDeleted;
}
