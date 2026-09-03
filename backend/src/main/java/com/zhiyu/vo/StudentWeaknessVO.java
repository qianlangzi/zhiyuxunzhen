package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 学生薄弱知识点列表项（PRD 8.9）
 */
@Data
@Builder
public class StudentWeaknessVO {
    private Long id;
    private String knowledgeTag;
    /** 掌握度 0.00 ~ 1.00 */
    private BigDecimal weaknessScore;
    private Integer evidenceCount;
    /** 推荐路径 JSON */
    private String recommendedPathJson;
    private LocalDateTime lastUpdated;
}
