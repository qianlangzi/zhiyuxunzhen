package com.zhiyu.service;

import com.zhiyu.vo.CaptchaResponse;

/**
 * 图形/数学验证码服务（防盗刷）
 */
public interface CaptchaService {

    /**
     * 生成一道数学验证题（如 "3 + 5 = ?"）
     * 同时做 IP 维度限流，防止恶意刷取。
     *
     * @param clientIp 客户端 IP，用于限流
     * @return 验证题信息（captchaId + question）
     */
    CaptchaResponse generate(String clientIp);

    /**
     * 校验并消费验证码（一次性）。
     * 校验失败累计错误次数，超过阈值自动失效。
     *
     * @param captchaId  验证题 ID
     * @param answer     用户提交的答案
     * @return true=校验通过
     */
    boolean verifyAndConsume(String captchaId, String answer);
}
