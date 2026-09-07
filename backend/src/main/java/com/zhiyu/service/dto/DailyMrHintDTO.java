package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 每日病历 · 段落教练请求（AI 三级提示梯度）
 */
@Data
public class DailyMrHintDTO {

    @NotNull(message = "排期ID不能为空")
    private Long scheduleId;

    /** 段落 key，如 history_present */
    @NotBlank(message = "段落key不能为空")
    private String segmentKey;

    /** 提示等级：1追问 2定向提示 3示范片段（前端控制点击次数递增） */
    private Integer hintLevel = 1;
}
