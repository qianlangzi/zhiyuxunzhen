package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 学生作业详情（待办作业查看 + 提交大病历）
 */
@Data
@Builder
public class StudentAssignmentDetailVO {
    private Long instanceId;
    private Long assignmentId;
    private String assignmentTitle;
    private String assignmentDescription;
    private Long caseId;
    private String caseTitle;
    private String department;
    private LocalDateTime deadline;
    private Boolean allowLateSubmit;
    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private LocalDateTime submitTime;
    private String medicalRecordText;
    /** 格式盾牌校验结果 JSON（未提交为 null） */
    private String formatCheckResult;
    /** 是否已提交（status 在 2/3/4/5 之间） */
    private Boolean submitted;
}