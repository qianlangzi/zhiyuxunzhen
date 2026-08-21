package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.service.CaptchaService;
import com.zhiyu.vo.CaptchaResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.UUID;

/**
 * 图形验证码服务实现（字母+数字图片，防盗刷）。
 *
 * 相比纯算术题，图片字符码可显著提高机器自动破解成本。
 * 防护策略：
 * 1. 每道题有效期 5 分钟，单次使用后即失效
 * 2. 单题最多尝试 3 次，超限自动作废
 * 3. IP 维度限流：每小时最多生成 30 道题，防止恶意刷取
 * 4. 答案只以图片形式返回，绝不出现在接口响应文本
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RedisCaptchaService implements CaptchaService {

    private static final Duration CAPTCHA_TTL = Duration.ofMinutes(5);
    private static final Duration IP_WINDOW = Duration.ofHours(1);
    private static final int IP_HOURLY_LIMIT = 30;
    private static final int ATTEMPT_LIMIT = 3;

    /** 不易混淆的字符集：去掉 0/O、1/I/L、q 等易误判字符 */
    private static final String CHARS = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
    private static final int CODE_LENGTH = 4;

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

        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            sb.append(CHARS.charAt(secureRandom.nextInt(CHARS.length())));
        }
        String code = sb.toString();

        String captchaId = UUID.randomUUID().toString().replace("-", "");
        redisTemplate.opsForValue().set(
                "auth:captcha:answer:" + captchaId,
                code,
                CAPTCHA_TTL);
        redisTemplate.opsForValue().set(
                "auth:captcha:attempts:" + captchaId,
                "0",
                CAPTCHA_TTL);

        // 绝不在响应文本里返回 code，答案只经 generateImage 以图片形式下发
        return new CaptchaResponse(captchaId, (int) CAPTCHA_TTL.toSeconds());
    }

    @Override
    public byte[] generateImage(String captchaId) {
        String code = redisTemplate.opsForValue().get("auth:captcha:answer:" + captchaId);
        BufferedImage image = renderImage(code == null ? "????" : code);
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(image, "png", out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new BizException(ResultCode.INTERNAL_ERROR, "验证码图片生成失败");
        }
    }

    private BufferedImage renderImage(String code) {
        int width = 140;
        int height = 46;
        BufferedImage img = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setColor(Color.WHITE);
        g.fillRect(0, 0, width, height);

        // 干扰线
        g.setColor(new Color(205, 211, 222));
        for (int i = 0; i < 7; i++) {
            g.drawLine(secureRandom.nextInt(width), secureRandom.nextInt(height),
                    secureRandom.nextInt(width), secureRandom.nextInt(height));
        }

        // 逐字符绘制，带随机旋转与偏移
        int charX = 16;
        for (int i = 0; i < code.length(); i++) {
            g.setFont(new Font("SansSerif", Font.BOLD, 30));
            int r = 30 + secureRandom.nextInt(110);
            int gg = 60 + secureRandom.nextInt(70);
            int b = 20 + secureRandom.nextInt(60);
            g.setColor(new Color(r, gg, b));
            double angle = (secureRandom.nextDouble() - 0.5) * 0.55;
            Graphics2D gc = (Graphics2D) g.create();
            gc.rotate(angle, charX, height / 2.0);
            gc.drawString(String.valueOf(code.charAt(i)), charX, (int) (height * 0.78));
            gc.dispose();
            charX += 29;
        }

        // 干扰噪点
        for (int i = 0; i < 90; i++) {
            int x = secureRandom.nextInt(width);
            int y = secureRandom.nextInt(height);
            img.setRGB(x, y,
                    new Color(120 + secureRandom.nextInt(135),
                            120 + secureRandom.nextInt(135),
                            120 + secureRandom.nextInt(135)).getRGB());
        }
        g.dispose();
        return img;
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

        if (stored.equalsIgnoreCase(answer.trim())) {
            redisTemplate.delete(answerKey);
            redisTemplate.delete(attemptsKey);
            return true;
        }
        return false;
    }
}
