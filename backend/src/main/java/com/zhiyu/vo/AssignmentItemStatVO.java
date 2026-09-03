package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 作业进度-任务项统计（组合任务包）
 */
@Data
@Builder
public class AssignmentItemStatVO {
    private Long itemId;
    /** CASE / PRACTICE / READING */
    private String itemType;
    private String title;
    /** 学生总数 */
    private Long total;
    /** 已完成数 */
    private Long completed;
    /** CASE:待复核数 */
    private Long pendingReview;
    /** PRACTICE:平均分（0-100） */
    private Double avgScore;
}
