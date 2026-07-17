package com.zhiyu.service.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 教师人工复核 AI 批阅请求（PRD 4.4.4 / 5.3 第 7 步）
 * 教师可覆盖 AI 分数、扣分项、评语；最终成绩以教师复核结果为准
 */
@Data
public class ReviewOverrideDTO {

    /** 被覆盖的 AI 批阅记录 ID（必填，留痕） */
    @NotNull(message = "被覆盖的AI批阅ID不能为空")
    private Long overrideFromReviewId;

    /** 教师最终评分（0-100） */
    @NotNull(message = "评分不能为空")
    @DecimalMin(value = "0.0", message = "评分不能低于0")
    @DecimalMax(value = "100.0", message = "评分不能高于100")
    private BigDecimal totalScore;

    /** 错误列表 JSON（位置、类型、建议） */
    private String mistakesJson;

    /** 综合评语 */
    private String reviewComment;
}
