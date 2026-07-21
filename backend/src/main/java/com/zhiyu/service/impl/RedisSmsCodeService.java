package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
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
    private static final int ATTEMPT_LIMIT = 5;

    private final StringRedisTemplate redisTemplate;
    private final PasswordEncoder passwordEncoder;
    private final Environment environment;
    private final SecureRandom secureRandom = new SecureRandom();

    @Value("${zhiyu.sms.provider:}")
    private String provider;

    @Override
    public SmsCodeResponse sendCode(String phone) {
        boolean development = environment.acceptsProfiles(Profiles.of("dev", "test"));
        if (!development && (provider == null || provider.isBlank())) {
            throw new BizException(ResultCode.SMS_SERVICE_NOT_CONFIGURED);
        }
        if (!development) {
            throw new BizException(ResultCode.SMS_SERVICE_NOT_CONFIGURED,
                    "短信厂商发送器尚未配置，请补充 SMS_PROVIDER 及厂商密钥");
        }

        String cooldownKey = key("cooldown", phone);
        if (Boolean.TRUE.equals(redisTemplate.hasKey(cooldownKey))) {
            throw new BizException(ResultCode.SMS_CODE_TOO_FREQUENT);
        }

        String hourlyKey = key("hourly", phone);
        Long count = redisTemplate.opsForValue().increment(hourlyKey);
        if (count != null && count == 1L) {
            redisTemplate.expire(hourlyKey, HOURLY_WINDOW);
        }
        if (count != null && count > HOURLY_LIMIT) {
            throw new BizException(ResultCode.SMS_CODE_TOO_FREQUENT,
                    "该手机号本小时获取验证码次数已达上限");
        }

        String code = String.format("%06d", secureRandom.nextInt(1_000_000));
        redisTemplate.opsForValue().set(key("code", phone), passwordEncoder.encode(code), CODE_TTL);
        redisTemplate.opsForValue().set(key("attempts", phone), "0", CODE_TTL);
        redisTemplate.opsForValue().set(cooldownKey, "1", COOLDOWN);
        log.info("开发环境短信验证码 phone={} code={}", maskPhone(phone), code);
        return new SmsCodeResponse(true, Math.toIntExact(CODE_TTL.toSeconds()), code);
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
