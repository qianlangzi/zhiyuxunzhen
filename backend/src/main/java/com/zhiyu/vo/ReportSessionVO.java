package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 复盘报告单会话明细（PRD 4.11）
 */
@Data
@Builder
public class ReportSessionVO {
    private Long sessionId;
    private Long caseId;
    private String caseTitle;
    /** 0进行中 1已完成 2异常中断 */
    private Integer status;
    /** 四维评分 JSON */
    private String osceScoreJson;
    private BigDecimal totalExamCost;
    private LocalDateTime endedAt;
    private LocalDateTime createdAt;
    /** AI 生成的 PDF URL（PRD 4.11.3），AI 不可用时为 null */
    private String pdfUrl;
}
