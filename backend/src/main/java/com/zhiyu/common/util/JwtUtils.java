package com.zhiyu.common.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 工具：签发、解析、校验（PRD 10.3）
 * SecretKey 在 @PostConstruct 时初始化一次，避免重复构造
 */
@Slf4j
@Component
public class JwtUtils {

    @Value("${zhiyu.jwt.secret}")
    private String secret;

    @Value("${zhiyu.jwt.expire-hours}")
    private long expireHours;

    @Value("${zhiyu.jwt.refresh-expire-hours}")
    private long refreshExpireHours;

    private SecretKey key;

    @PostConstruct
    public void init() {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("JWT secret 长度不足 32 字节，请检查 zhiyu.jwt.secret 配置");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        log.info("JwtUtils 初始化完成，token 有效期 {}h，refresh 有效期 {}h", expireHours, refreshExpireHours);
    }

    /**
     * 签发访问 token（PRD 9.1：Payload 含 user_id、role、audit_status）
     */
    public String issueToken(Long userId, String username, Integer role, Integer auditStatus) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("username", username)
                .claim("role", role)
                .claim("auditStatus", auditStatus)
                .claim("type", "access")
                .issuedAt(new Date(now))
                .expiration(new Date(now + expireHours * 3600_000L))
                .signWith(key)
                .compact();
    }

    /** 签发刷新 token，仅含 userId，有效期更长 */
    public String issueRefreshToken(Long userId) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("type", "refresh")
                .issuedAt(new Date(now))
                .expiration(new Date(now + refreshExpireHours * 3600_000L))
                .signWith(key)
                .compact();
    }

    /**
     * 解析 token，返回 Claims；签名错误或过期抛 JwtException
     */
    public Claims parseToken(String token) throws JwtException {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    /** 校验 token 是否有效（不抛异常） */
    public boolean isValid(String token) {
        try {
            parseToken(token);
            return true;
        } catch (JwtException e) {
            return false;
        }
    }

    public long getAccessExpireMs() {
        return expireHours * 3600_000L;
    }

    public long getRefreshExpireMs() {
        return refreshExpireHours * 3600_000L;
    }
}
