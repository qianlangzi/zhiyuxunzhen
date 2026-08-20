package com.zhiyu.service.impl;

import com.zhiyu.client.JuheSmsClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.service.CaptchaService;
import com.zhiyu.service.SmsCodeService;
import com.zhiyu.vo.SmsCodeResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;

@Slf4j
@Service
@RequiredArgsConstructor
public class RedisSmsCodeService implements SmsCodeService {

    private static final Duration CODE_TTL = Duration.ofMinutes(5);
    private static final Duration COOLDOWN = Duration.ofSeconds(60);
    private static final Duration HOURLY_WINDOW = Duration.ofHours(1);
    private static final int HOURLY_LIMIT = 5;
    private static final int IP_HOURLY_LIMIT = 10;
    private static final int ATTEMPT_LIMIT = 5;

    private final StringRedisTemplate redisTemplate;
    private final PasswordEncoder passwordEncoder;
    private final Environment environment;
    private final SecureRandom secureRandom = new SecureRandom();
    private final JuheSmsClient juheSmsClient;
    private final CaptchaService captchaService;

    @Value("${zhiyu.sms.provider:}")
    private String provider;

    @Override
    public SmsCodeResponse sendCode(String phone, String captchaId, String captchaAnswer, String clientIp) {
        boolean development = environment.acceptsProfiles(Profiles.of("dev", "test"));

        // 1. 先校验图形验证码（防盗刷，防机器人）
        if (!captchaService.verifyAndConsume(captchaId, captchaAnswer)) {
            throw new BizException(ResultCode.CAPTCHA_INVALID);
        }

        // 2. 手机号冷却检查
        String cooldownKey = key("cooldown", phone);
        if (Boolean.TRUE.equals(redisTemplate.hasKey(cooldownKey))) {
            throw new BizException(ResultCode.SMS_CODE_TOO_FREQUENT);
        }

        // 3. 手机号小时限流
        String hourlyKey = key("hourly", phone);
        Long count = redisTemplate.opsForValue().increment(hourlyKey);
        if (count != null && count == 1L) {
            redisTemplate.expire(hourlyKey, HOURLY_WINDOW);
        }
        if (count != null && count > HOURLY_LIMIT) {
            throw new BizException(ResultCode.SMS_CODE_TOO_FREQUENT,
                    "该手机号本小时获取验证码次数已达上限");
        }

        // 4. IP 维度限流（防止攻击者切换手机号刷短信）
        if (clientIp != null && !clientIp.isBlank()) {
            String ipKey = "auth:sms:ip:" + clientIp;
            Long ipCount = redisTemplate.opsForValue().increment(ipKey);
            if (ipCount != null && ipCount == 1L) {
                redisTemplate.expire(ipKey, HOURLY_WINDOW);
            }
            if (ipCount != null && ipCount > IP_HOURLY_LIMIT) {
                throw new BizException(ResultCode.IP_SMS_LIMIT);
            }
        }

        String code = String.format("%06d", secureRandom.nextInt(1_000_000));

        // 生产环境：通过短信厂商发送
        if (!development) {
            if ("juhe".equalsIgnoreCase(provider)) {
                JuheSmsClient.SendResult result = juheSmsClient.send(phone, code);
                if (!result.success()) {
                    throw new BizException(ResultCode.SMS_SERVICE_NOT_CONFIGURED,
                            "短信发送失败：" + result.errorMessage());
                }
                log.info("短信已发送 phone={} tplId={}", maskPhone(phone),
                        "juhe-" + provider);
            } else {
                throw new BizException(ResultCode.SMS_SERVICE_NOT_CONFIGURED,
                        "短信厂商发送器尚未配置: provider=" + provider
                                + "，支持的值: juhe（聚合数据）");
            }
        } else {
            // 开发环境：仅打印日志
            log.info("开发环境短信验证码 phone={} code={}", maskPhone(phone), code);
        }

        redisTemplate.opsForValue().set(key("code", phone), passwordEncoder.encode(code), CODE_TTL);
        redisTemplate.opsForValue().set(key("attempts", phone), "0", CODE_TTL);
        redisTemplate.opsForValue().set(cooldownKey, "1", COOLDOWN);
        // 生产环境禁止把验证码回吐给调用方（否则短信校验形同虚设，可被用于任意账号接管）；
        // 仅 dev/test 环境回显便于联调。
        return new SmsCodeResponse(true, Math.toIntExact(CODE_TTL.toSeconds()), development ? code : null);
    }

    @Override
    public void verifyAndConsume(String phone, String code) {
        String codeKey = key("code", phone);
        String attemptsKey = key("attempts", phone);
        String encoded = redisTemplate.opsForValue().get(codeKey);
        if (encoded == null) {
            throw new BizException(ResultCode.PHONE_OR_CODE_ERROR);
        }

        Long attempts = redisTemplate.opsForValue().increment(attemptsKey);
        if (attempts != null && attempts > ATTEMPT_LIMIT) {
            redisTemplate.delete(codeKey);
            redisTemplate.delete(attemptsKey);
            throw new BizException(ResultCode.PHONE_OR_CODE_ERROR, "验证码错误次数过多，请重新获取");
        }
        if (!passwordEncoder.matches(code, encoded)) {
            throw new BizException(ResultCode.PHONE_OR_CODE_ERROR);
        }
        redisTemplate.delete(codeKey);
        redisTemplate.delete(attemptsKey);
    }

    private String key(String type, String phone) {
        return "auth:sms:" + type + ":" + phone;
    }

    private String maskPhone(String phone) {
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }
}
