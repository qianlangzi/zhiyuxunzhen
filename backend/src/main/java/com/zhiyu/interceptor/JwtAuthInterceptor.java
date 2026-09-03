package com.zhiyu.interceptor;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.service.OnlineStatsService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * JWT 鉴权拦截器（PRD 10.3）
 * 解析 Authorization: Bearer xxx，校验签名与过期，将用户信息注入 UserContext
 */
@Slf4j
@Component
public class JwtAuthInterceptor implements HandlerInterceptor {

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private OnlineStatsService onlineStatsService;

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse resp, Object handler) {
        String auth = req.getHeader("Authorization");
        if (auth == null || !auth.startsWith("Bearer ")) {
            throw new BizException(ResultCode.UNAUTHORIZED);
        }
        String token = auth.substring(7).trim();
        try {
            Claims claims = jwtUtils.parseToken(token);
            if (!"access".equals(claims.get("type", String.class))) {
                throw new BizException(ResultCode.UNAUTHORIZED, "无效的token类型");
            }
            UserContext.LoginUser user = UserContext.LoginUser.builder()
                    .userId(Long.valueOf(claims.getSubject()))
                    .username(claims.get("username", String.class))
                    .role(claims.get("role", Integer.class))
                    .auditStatus(claims.get("auditStatus", Integer.class))
                    .credentialVersion(claims.get("credentialVersion", Integer.class))
                    .build();
            UserContext.set(user);
            // 用户数据看板：在线心跳打点（内部 try/catch，Redis 故障不影响鉴权）
            onlineStatsService.touch(user.getUserId(), user.getRole());
            return true;
        } catch (ExpiredJwtException e) {
            throw new BizException(ResultCode.TOKEN_EXPIRED);
        } catch (JwtException e) {
            log.debug("JWT 解析失败: {}", e.getMessage());
            throw new BizException(ResultCode.UNAUTHORIZED);
        }
    }

    @Override
    public void afterCompletion(HttpServletRequest req, HttpServletResponse resp, Object handler, Exception ex) {
        UserContext.clear();
    }
}
