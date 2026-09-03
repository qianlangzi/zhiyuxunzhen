package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 关键动作埋点请求（P2-3）
 */
@Data
public class ActionTrackRequest {

    @NotBlank(message = "动作编码不能为空")
    @Size(max = 64, message = "动作编码长度不能超过64")
    private String action;

    @Size(max = 500, message = "详情长度不能超过500")
    private String detail;
}
