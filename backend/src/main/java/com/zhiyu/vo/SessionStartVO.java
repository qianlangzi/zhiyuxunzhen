package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 学生启动问诊会话响应（PRD 5.2 第 1 步）
 */
@Data
@Builder
public class SessionStartVO {

    private Long sessionId;

    private Long studentId;

    private Long caseId;

    private Long assignmentInstanceId;

    /** 初始检查费用 = 0 */
    private BigDecimal totalExamCost;

    /** 0进行中 1已完成 2异常中断 */
    private Integer status;

    private LocalDateTime createdAt;
}
