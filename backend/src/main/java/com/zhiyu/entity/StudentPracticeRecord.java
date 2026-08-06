package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

/**
 * 学生基础题练习记录表
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("student_practice_record")
public class StudentPracticeRecord extends BaseEntity {

    private Long studentId;

    private Long questionId;

    private String selectedAnswer;

    private Boolean isCorrect;

    private LocalDateTime answeredAt;
}