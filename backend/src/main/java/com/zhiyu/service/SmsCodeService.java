package com.zhiyu.service;

import com.zhiyu.vo.SmsCodeResponse;

/** 手机登录验证码的生成、限流和一次性校验。 */
public interface SmsCodeService {

    SmsCodeResponse sendCode(String phone);

    void verifyAndConsume(String phone, String code);
}
