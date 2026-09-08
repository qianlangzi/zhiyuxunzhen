package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class TeacherAssignmentListVO {
    private Long id;
    private String title;
    private Long caseId;
    private String caseTitle;
    private LocalDateTime deadline;
    /** 开始时间（定时发布），为空表示已发布 */
    private LocalDateTime startTime;
    /** 是否允许补交 */
    private Boolean allowLateSubmit;
    /** 补交截止时间 */
    private LocalDateTime lateDeadline;
    /** 作业总分 */
    private BigDecimal totalScore;
    /** 成绩公布方式 IMMEDIATE/AFTER_DEADLINE/MANUAL */
    private String scorePublishMode;
    /** 答案公布方式 IMMEDIATE/AFTER_DEADLINE/MANUAL */
    private String answerPublishMode;
    /** 题目乱序 */
    private Boolean shuffleQuestions;
    /** 允许提交次数 */
    private Integer maxAttempts;
    /** 抄袭检测 */
    private Boolean plagiarismCheck;
    private Integer status;
    private Boolean requireMedicalRecord;
    private String antiCheatVariables;
    private List<String> classNames;
    private Long submittedCount;
    private Long studentCount;
    /** 组合任务包:任务项列表(存量单病例作业为空) */
    private List<AssignmentItemVO> items;
}
