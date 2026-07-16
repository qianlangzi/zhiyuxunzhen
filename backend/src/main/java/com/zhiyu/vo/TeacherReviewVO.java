package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 教师复核-批阅记录 VO（PRD 4.4.4 / 5.3 第 7 步）
 */
@Data
@Builder
public class TeacherReviewVO {

    private Long reviewId;

    private Long instanceId;

    /** AI / TEACHER */
    private String reviewerType;

    private BigDecimal totalScore;

    private String mistakesJson;

    private String reviewComment;

    /** 人工覆盖的 AI 批阅 ID（仅教师批阅有值） */
    private Long overrideFromReviewId;

    private Long reviewedBy;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
