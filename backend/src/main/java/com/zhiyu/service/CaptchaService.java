package com.zhiyu.service;

import com.zhiyu.vo.CaptchaResponse;

/**
 * 图形/数学验证码服务（防盗刷）
 */
public interface CaptchaService {

    /**
     * 生成一道图形验证码（字母+数字图片），同时做 IP 维度限流
     *
     * @param clientIp 客户端 IP，用于限流
     * @return 验证码信息（captchaId + 有效期）
     */
    CaptchaResponse generate(String clientIp);

    /**
     * 根据 captchaId 渲染验证码 PNG 图片（答案只以图片形式下发，绝不出现在接口响应文本里）
     *
     * @param captchaId 验证码 ID
     * @return PNG 图片字节
     */
    byte[] generateImage(String captchaId);

    /**
     * 校验并消费验证码（一次性）。
     * 校验失败累计错误次数，超过阈值自动失效。
     *
     * @param captchaId  验证码 ID
     * @param answer     用户图片中识别并输入的字符
     * @return true=校验通过
     */
    boolean verifyAndConsume(String captchaId, String answer);
}
