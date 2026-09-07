package com.zhiyu.interceptor;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.UUID;

/**
 * 全链路 trace 拦截器（跨系统排障）。
 *
 * 为每个入站请求生成/透传一条 traceId：
 * <ul>
 *   <li>优先取入站 {@code X-Trace-Id} 头（移动端或上游已带则接力）；</li>
 *   <li>否则自生成一条全程统一的 uuid；</li>
 *   <li>写入 SLF4J MDC（key=traceId），AiHttpClient 出站调 AI 时透传同名头，
 *       使 Spring Boot 与 AI 中台日志可按同一 trace 关联；</li>
 *   <li>写回响应头，方便调用方与本端日志对齐。</li>
 * </ul>
 * 注册为拦截器链第 0 位，先于所有鉴权/业务拦截器执行。
 */
@Component
public class TraceIdInterceptor implements HandlerInterceptor {

    public static final String HEADER = "X-Trace-Id";
    public static final String MDC_KEY = "traceId";

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String traceId = request.getHeader(HEADER);
        if (traceId == null || traceId.isBlank()) {
            traceId = UUID.randomUUID().toString().replace("-", "");
        }
        MDC.put(MDC_KEY, traceId);
        // 透传回调用方，便于与本端日志按同一 trace 对齐
        response.setHeader(HEADER, traceId);
        request.setAttribute(TraceIdInterceptor.class.getName() + ".traceId", traceId);
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                Object handler, Exception ex) {
        // 防止 MDC 值污染连接复用的后续线程
        MDC.remove(MDC_KEY);
    }
}