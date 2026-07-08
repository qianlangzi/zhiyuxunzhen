package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

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
    private LocalDateTime deadline;
    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
}
