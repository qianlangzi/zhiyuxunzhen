package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class SmsCodeRequest {

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    /** 图形验证码 ID（防盗刷必填） */
    @NotBlank(message = "请先完成图形验证")
    private String captchaId;

    /** 图形验证码答案（防盗刷必填） */
    @NotBlank(message = "请输入图形验证码答案")
    private String captchaAnswer;
}
