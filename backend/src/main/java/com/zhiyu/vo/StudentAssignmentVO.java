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
    private LocalDateTime deadline;
    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private BigDecimal score;
    /** 组合任务包:任务项摘要 */
    private List<StudentItemVO> items;
}
