package com.zhiyu.service.dto.internal;

import lombok.Data;

import java.math.BigDecimal;

/**
 * AI 批阅结果回调（PRD 9.4）
 * FastAPI 完成大病历批阅后回调写入批阅记录
 */
@Data
public class ReviewCallbackDTO {

    private Long instanceId;

    /** 总分 */
    private BigDecimal totalScore;

    /** 错误列表、位置、类型、建议 JSON */
    private String mistakesJson;

    /** 批阅评语 */
    private String reviewComment;
}
