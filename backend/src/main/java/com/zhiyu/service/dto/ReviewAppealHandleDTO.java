package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 教师处理批阅申诉请求
 * status: 1已处理(改分/复核) / 2已驳回
 * newScore 可选：非空时同步覆盖该批阅得分并同步实例/任务项
 */
@Data
public class ReviewAppealHandleDTO {

    @NotNull(message = "处理状态不能为空")
    private Integer status;

    @NotBlank(message = "处理回复不能为空")
    private String reply;

    private BigDecimal newScore;
}