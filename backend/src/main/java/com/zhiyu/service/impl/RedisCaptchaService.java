package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.service.CaptchaService;
import com.zhiyu.vo.CaptchaResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.UUID;

/**
 * 数学验证码服务实现（防盗刷）。
 *
 * 防护策略：
 * 1. 每道题有效期 5 分钟，单次使用后即失效
 * 2. 单题最多尝试 3 次，超限自动作废
 * 3. IP 维度限流：每小时最多生成 30 道题，防止恶意刷取
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RedisCaptchaService implements CaptchaService {

    private static final Duration CAPTCHA_TTL = Duration.ofMinutes(5);
    private static final Duration IP_WINDOW = Duration.ofHours(1);
    private static final int IP_HOURLY_LIMIT = 30;
    private static final int ATTEMPT_LIMIT = 3;

    private final StringRedisTemplate redisTemplate;
    private final SecureRandom secureRandom = new SecureRandom();

    @Override
    public CaptchaResponse generate(String clientIp) {
        // IP 限流
        if (clientIp != null && !clientIp.isBlank()) {
            String ipKey = "auth:captcha:ip:" + clientIp;
            Long count = redisTemplate.opsForValue().increment(ipKey);
            if (count != null && count == 1L) {
                redisTemplate.expire(ipKey, IP_WINDOW);
            }
            if (count != null && count > IP_HOURLY_LIMIT) {
                throw new BizException(ResultCode.CAPTCHA_TOO_FREQUENT,
                        "验证码请求过于频繁，请稍后再试");
            }
        }

        int a = 1 + secureRandom.nextInt(20);
        int b = 1 + secureRandom.nextInt(20);
        int op = secureRandom.nextInt(3); // 0:+ 1:- 2:×
        int answer;
        String question;
        switch (op) {
            case 1:
                if (a < b) { int t = a; a = b; b = t; }
                answer = a - b;
                question = a + " - " + b + " = ?";
                break;
            case 2:
                answer = a * b;
                question = a + " × " + b + " = ?";
                break;
            default:
                answer = a + b;
                question = a + " + " + b + " = ?";
                break;
        }

        String captchaId = UUID.randomUUID().toString().replace("-", "");
        redisTemplate.opsForValue().set(
                "auth:captcha:answer:" + captchaId,
                String.valueOf(answer),
                CAPTCHA_TTL);
        redisTemplate.opsForValue().set(
                "auth:captcha:attempts:" + captchaId,
                "0",
                CAPTCHA_TTL);

        return new CaptchaResponse(captchaId, question, (int) CAPTCHA_TTL.toSeconds());
    }

    @Override
    public boolean verifyAndConsume(String captchaId, String answer) {
        if (captchaId == null || captchaId.isBlank() || answer == null || answer.isBlank()) {
            return false;
        }
        String answerKey = "auth:captcha:answer:" + captchaId;
        String attemptsKey = "auth:captcha:attempts:" + captchaId;

        String stored = redisTemplate.opsForValue().get(answerKey);
        if (stored == null) {
            return false; // 已过期或不存在
        }

        Long attempts = redisTemplate.opsForValue().increment(attemptsKey);
        if (attempts != null && attempts > ATTEMPT_LIMIT) {
            redisTemplate.delete(answerKey);
            redisTemplate.delete(attemptsKey);
            return false;
        }

        try {
            int userAns = Integer.parseInt(answer.trim());
            int realAns = Integer.parseInt(stored.trim());
            if (userAns == realAns) {
                redisTemplate.delete(answerKey);
                redisTemplate.delete(attemptsKey);
                return true;
            }
        } catch (NumberFormatException ignored) {
        }
        return false;
    }
}
