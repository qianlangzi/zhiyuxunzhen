package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 批阅申诉（学生对大病历/主观题批阅结果有异议时发起，教师处理）
 * status: 0待处理 1已处理(已复核/改分) 2已驳回
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("review_appeal")
public class ReviewAppeal extends BaseEntity {

    /** 被申诉的批阅记录 ID (medical_record_review.id) */
    private Long reviewId;

    /** 作业实例 ID（学生发起时冗余，便于教师列表过滤与展示） */
    private Long instanceId;

    /** 发起申诉的学生 */
    private Long studentId;

    /** 申诉理由 */
    private String reason;

    /** 0待处理 1已处理 2已驳回 */
    private Integer status;

    /** 教师处理回复 */
    private String reply;

    /** 处理的教师 */
    private Long reviewedBy;

    public static final int STATUS_PENDING = 0;
    public static final int STATUS_HANDLED = 1;
    public static final int STATUS_REJECTED = 2;
}