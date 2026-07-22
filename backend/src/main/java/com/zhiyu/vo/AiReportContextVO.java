package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

/** AI 报告生成所需的只读事实，由内部鉴权接口提供。 */
@Data
@Builder
public class AiReportContextVO {
    private Long sessionId;
    private Long studentId;
    private Long caseId;
    private String caseTitle;
    private Integer status;
    private String osceScoreJson;
    private String finalReport;
    private BigDecimal totalExamCost;
    private List<AiSessionContextVO.Message> messages;
}
