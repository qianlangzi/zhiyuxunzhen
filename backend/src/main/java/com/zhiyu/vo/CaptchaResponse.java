package com.zhiyu.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Value;

/**
 * 图形验证码返回体（字母+数字图片）。
 *
 * 安全约束：答案只以图片形式下发，本响应绝不包含 code/question 明文，
 * 防止被机器直接抓取答案绕过图形验证。
 * imageBase64 为渲染好的 PNG 图片 base64，供移动端单次请求原子交付，
 * 避免「元数据 + 图片」两次独立请求带来的超时挂起 / 自动重发 / 重复限流问题。
 */
@Value
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class CaptchaResponse {
    /** 验证码 ID（提交时回传，图片接口也依赖此 ID） */
    String captchaId;
    /** 有效期（秒） */
    int expiresIn;
    /** 渲染好的验证码 PNG 图片（base64），与 captchaId 同一请求返回 */
    String imageBase64;
}
