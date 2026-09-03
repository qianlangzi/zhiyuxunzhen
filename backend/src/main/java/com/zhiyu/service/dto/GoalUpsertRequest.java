package com.zhiyu.service.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 学生学习目标设定请求（P2-1）
 */
@Data
public class GoalUpsertRequest {

    @Size(max = 200, message = "目标标题长度不能超过200")
    private String title;

    @Size(max = 100, message = "量化指标长度不能超过100")
    private String targetMetric;

    /** yyyy-MM-dd */
    private String targetDate;
}
