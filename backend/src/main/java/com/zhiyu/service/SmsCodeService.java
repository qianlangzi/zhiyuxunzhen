package com.zhiyu.service;

import com.zhiyu.vo.SmsCodeResponse;

/**
 * 手机登录验证码的生成、限流和一次性校验。
 */
public interface SmsCodeService {

    /**
     * 发送短信验证码。
     * 内部会先校验图形验证码（防盗刷），再做手机号与 IP 维度限流。
     *
     * @param phone          手机号
     * @param captchaId      图形验证码 ID
     * @param captchaAnswer  图形验证码答案
     * @param clientIp       客户端 IP（用于 IP 维度限流，可为 null）
     */
    SmsCodeResponse sendCode(String phone, String captchaId, String captchaAnswer, String clientIp);

    void verifyAndConsume(String phone, String code);
}
