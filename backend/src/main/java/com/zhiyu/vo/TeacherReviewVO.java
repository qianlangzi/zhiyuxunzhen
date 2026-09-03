package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

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

    /** 任务项进度 ID（组合包） */
    private Long itemProgressId;

    /** 学生提交的大病历正文（真实数据，非壳） */
    private String medicalRecordText;

    /** 格式盾牌:是否通过 */
    private Boolean formatShieldPassed;

    /** 格式盾牌:明细描述 */
    private String formatShieldDetail;

    /** AI 扣分明细列表 [{name, description, points}] */
    private List<Map<String, Object>> deductions;

    /** AI 评分等级（良好/优秀/...） */
    private String aiScoreLevel;
}
