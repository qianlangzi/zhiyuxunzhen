package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

/** 对学生和病例广场公开的病例信息。 */
@Data
@Builder
public class CaseMarketDetailVO {
    private Long id;
    private String title;
    private String department;
    private Integer difficulty;
    private String patientProfile;
    private String knowledgeTags;
    private Integer referenceCount;
    private BigDecimal ratingAvg;
    private String creatorName;
}
