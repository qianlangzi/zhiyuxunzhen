package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDate;

/**
 * 学生学习目标表（P2-1 学习档案/目标管理）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("student_goal")
public class StudentGoal extends BaseEntity {

    private Long studentId;

    private String title;

    /** 量化指标，如 OSCE 均分≥85 */
    private String targetMetric;

    private LocalDate targetDate;

    /** 0进行中 1已完成 */
    private Integer status;
}
