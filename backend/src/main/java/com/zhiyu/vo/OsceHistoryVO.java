package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * OSCE 考核历史记录（列表项）
 */
@Data
@Builder
public class OsceHistoryVO {
    private Long sessionId;
    private Long caseId;
    private String caseTitle;
    private String department;
    /** 总分 0-100 */
    private Double totalScore;
    /** 四维评分 JSON（前端可据此展示） */
    private String osceScoreJson;
    private BigDecimal totalExamCost;
    /** 1已完成 */
    private Integer status;
    private LocalDateTime endedAt;
    private LocalDateTime createdAt;
}