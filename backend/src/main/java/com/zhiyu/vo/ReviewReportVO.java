package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 学生复盘报告（PRD 4.11）
 * 简化实现：返回报告内容 JSON，后续可接 FastAPI 生成 PDF
 */
@Data
@Builder
public class ReviewReportVO {
    private Long studentId;
    private LocalDateTime generatedAt;
    private Integer sessionCount;
    private BigDecimal totalExamCostSum;
    private List<ReportSessionVO> sessions;
}
