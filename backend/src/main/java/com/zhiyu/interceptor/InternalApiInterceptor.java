package com.zhiyu.interceptor;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 内部接口鉴权拦截器（PRD 9.4）
 * FastAPI 回调 Spring Boot 的 /api/internal/** 接口使用独立 token，不走用户 JWT
 */
@Component
public class InternalApiInterceptor implements HandlerInterceptor {

    @Value("${zhiyu.ai.internal-token}")
    private String internalToken;

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse resp, Object handler) {
        String token = req.getHeader("X-Internal-Token");
        if (token == null || !token.equals(internalToken)) {
            throw new BizException(ResultCode.FORBIDDEN, "内部接口鉴权失败");
        }
        return true;
    }
}
