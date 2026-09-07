package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.Map;

/**
 * 每日病历提交（九段内容）请求
 */
@Data
public class DailyMrSubmitDTO {

    @NotNull(message = "排期ID不能为空")
    private Long scheduleId;

    /** 九段内容：{"chief_complaint":"...","history_present":"...",...} */
    @NotEmpty(message = "病历内容不能为空")
    private Map<String, String> segments;
}
