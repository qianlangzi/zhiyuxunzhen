package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

/**
 * 批阅记录表（PRD 8.5）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("medical_record_review")
public class MedicalRecordReview extends BaseEntity {

    private Long instanceId;

    /** AI / TEACHER */
    private String reviewerType;

    private BigDecimal totalScore;

    /** 错误列表、位置、类型、建议 JSON */
    private String mistakesJson;

    private String reviewComment;

    /** 人工覆盖的 AI 批阅 ID */
    private Long overrideFromReviewId;

    private Long reviewedBy;
}
