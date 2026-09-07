package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

/**
 * 每日病历段落表（V43）：九段逐段存储，支撑逐段批阅与 AI 段落教练。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("daily_case_segment")
public class DailyCaseSegment extends BaseEntity {

    private Long recordId;

    /** 段落 key，如 chief_complaint / history_present */
    private String segmentKey;

    /** 段序 1-9 */
    private Integer segmentOrder;

    /** 学生书写内容 */
    private String content;

    /** 该段得分 */
    private BigDecimal score;

    /** 该段满分 */
    private BigDecimal fullScore;

    /** 段落级反馈 JSON（缺陷 + 建议） */
    private String feedbackJson;
}
