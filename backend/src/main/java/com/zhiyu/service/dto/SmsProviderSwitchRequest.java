package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 管理端-切换短信服务商请求
 */
@Data
public class SmsProviderSwitchRequest {

    /** 目标服务商：aliyun_auth / juhe / off */
    @NotBlank(message = "provider 不能为空")
    private String provider;
}
