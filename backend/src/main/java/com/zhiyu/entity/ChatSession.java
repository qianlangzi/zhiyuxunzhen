package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 问诊会话表（PRD 8.6）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("chat_session")
public class ChatSession extends BaseEntity {

    private Long studentId;

    private Long caseId;

    private Long assignmentInstanceId;

    /** 组合包:病例任务项进度ID(存量作业为NULL) */
    private Long assignmentItemProgressId;

    /** 四维评分 JSON */
    private String osceScoreJson;

    private String finalReport;

    /** 最终思维树 JSON */
    private String reasoningTreeJson;

    private BigDecimal totalExamCost;

    /** 0进行中 1已完成 2异常中断 */
    private Integer status;

    private LocalDateTime endedAt;
}
