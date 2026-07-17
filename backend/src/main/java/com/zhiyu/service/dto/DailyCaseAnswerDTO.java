package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 学生提交每日一例答案请求（PRD 4.10.2）
 */
@Data
public class DailyCaseAnswerDTO {

    @NotNull(message = "排期ID不能为空")
    private Long scheduleId;

    /** 学生选择的诊断 */
    @NotBlank(message = "答案不能为空")
    private String answer;
}
