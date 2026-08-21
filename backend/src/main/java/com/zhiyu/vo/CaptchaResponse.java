package com.zhiyu.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Value;

/**
 * 图形验证码返回体（字母+数字图片）。
 *
 * 安全约束：答案只通过图片接口下发，本响应绝不包含 code/question，
 * 防止被机器直接抓取答案绕过图形验证。
 */
@Value
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class CaptchaResponse {
    /** 验证码 ID（提交时回传，图片接口也依赖此 ID） */
    String captchaId;
    /** 有效期（秒） */
    int expiresIn;
}
