package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

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
    /** 布置教师姓名 */
    private String teacherName;
    /** 归属班级名 */
    private String className;
    private LocalDateTime deadline;
    /** 开始时间（定时发布） */
    private LocalDateTime startTime;
    private Boolean allowLateSubmit;
    /** 补交截止时间 */
    private LocalDateTime lateDeadline;
    /** 作业总分 */
    private BigDecimal totalScore;
    /** 是否已过截止时间 */
    private Boolean overdue;
    /** 逾期后是否仍在补交窗口内 */
    private Boolean canSubmitLate;
    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private BigDecimal score;
    private LocalDateTime submitTime;
    private String medicalRecordText;
    /** 格式盾牌校验结果 JSON（未提交为 null） */
    private String formatCheckResult;
    /** 是否已提交（status 在 2/3/4/5 之间） */
    private Boolean submitted;
    /** 组合任务包:任务项详情列表 */
    private List<StudentItemDetailVO> items;
}