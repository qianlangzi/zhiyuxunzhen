package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 学生发起批阅申诉请求
 */
@Data
public class ReviewAppealCreateDTO {

    @NotBlank(message = "申诉理由不能为空")
    private String reason;
}