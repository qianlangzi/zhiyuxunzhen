package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 基础题提交答案 DTO
 */
@Data
public class PracticeAnswerDTO {

    @NotNull
    private Long questionId;

    /** 学生所选答案（选项 index 或判断答案） */
    @NotBlank
    private String selectedAnswer;
}