package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 学生反馈表（P2-3 真实用户数据）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("student_feedback")
public class StudentFeedback extends BaseEntity {

    private Long studentId;

    /** 功能 / 学习内容 / 使用问题 / 建议 / 其他 */
    private String category;

    /** 满意度 1-5，0=未评分 */
    private Integer rating;

    private String content;

    /** 0待处理 1已处理 */
    private Integer status;
}
