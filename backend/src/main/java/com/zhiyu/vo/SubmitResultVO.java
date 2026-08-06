package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 基础题提交判题结果 VO
 */
@Data
@Builder
public class SubmitResultVO {
    private Long questionId;
    private Boolean isCorrect;
    private String selectedAnswer;
    private String correctAnswer;
    private String explanation;
}