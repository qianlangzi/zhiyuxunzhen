package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 病例广场列表项（PRD 4.2）
 */
@Data
@Builder
public class CaseMarketListVO {
    private Long id;
    private String title;
    private String department;
    private Integer difficulty;
    private BigDecimal ratingAvg;
    private Integer referenceCount;
    private String creatorName;
    private String knowledgeTags;
    private LocalDateTime createdAt;
}
