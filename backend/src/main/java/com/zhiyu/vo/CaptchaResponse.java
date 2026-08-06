package com.zhiyu.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Value;

/**
 * 数学验证码返回体
 */
@Value
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class CaptchaResponse {
    /** 验证题 ID（提交时回传） */
    String captchaId;
    /** 验证题文本（如 "3 + 5 = ?"） */
    String question;
    /** 有效期（秒） */
    int expiresIn;
}
