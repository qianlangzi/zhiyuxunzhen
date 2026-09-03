package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 学生作业-任务项摘要（列表页用）
 */
@Data
@Builder
public class StudentItemVO {
    private Long itemId;
    /** CASE / PRACTICE / READING */
    private String itemType;
    private String title;
    /** 0未开始 1进行中 2已提交/格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private BigDecimal score;
}
