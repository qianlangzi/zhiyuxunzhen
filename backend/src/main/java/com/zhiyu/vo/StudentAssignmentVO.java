package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 学生作业列表项（PRD 9.1）
 */
@Data
@Builder
public class StudentAssignmentVO {
    private Long instanceId;
    private Long assignmentId;
    private String assignmentTitle;
    private Long caseId;
    private String caseTitle;
    /** 归属班级（作业目标班级名，支持学生端按课程分组汇总待办） */
    private String className;
    /** 归属班级 ID（学生端按课程分档跳转用） */
    private Long classId;
    /** 布置该作业的教师姓名（多科老师作业混排时区分来源） */
    private String teacherName;
    private LocalDateTime deadline;
    /** 开始时间（定时发布），为空表示已发布 */
    private LocalDateTime startTime;
    /** 是否允许补交 */
    private Boolean allowLateSubmit;
    /** 补交截止时间（allowLateSubmit=true 时生效） */
    private LocalDateTime lateDeadline;
    /** 作业总分 */
    private BigDecimal totalScore;
    /** 是否已过截止时间 */
    private Boolean overdue;
    /** 逾期后是否仍在补交窗口内（true=可继续提交） */
    private Boolean canSubmitLate;
    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private BigDecimal score;
    /** 组合任务包:任务项摘要 */
    private List<StudentItemVO> items;
}
