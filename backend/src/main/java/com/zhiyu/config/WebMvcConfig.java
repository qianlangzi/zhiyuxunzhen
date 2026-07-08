package com.zhiyu.config;

import com.zhiyu.interceptor.InternalApiInterceptor;
import com.zhiyu.interceptor.JwtAuthInterceptor;
import com.zhiyu.interceptor.PermissionInterceptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web MVC 配置（PRD 16.3.1）：注册拦截器链
 * 顺序：InternalApiInterceptor → JwtAuthInterceptor → PermissionInterceptor
 */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    @Autowired
    private JwtAuthInterceptor jwtAuthInterceptor;

    @Autowired
    private PermissionInterceptor permissionInterceptor;

    @Autowired
    private InternalApiInterceptor internalApiInterceptor;

    /** 不需要 JWT 鉴权的路径 */
    private static final String[] JWT_EXCLUDE = {
            "/api/v1/auth/login",
            "/api/v1/auth/refresh",
            "/api/v1/health",
            "/api/internal/**",
            "/swagger-ui/**",
            "/swagger-ui.html",
            "/v3/api-docs/**",
            "/actuator/**",
            "/error"
    };

    /** 内部接口（FastAPI 回调）路径 */
    private static final String[] INTERNAL_PATHS = {"/api/internal/**"};

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        // 1. 内部接口独立鉴权（不走 JWT）
        registry.addInterceptor(internalApiInterceptor)
                .addPathPatterns(INTERNAL_PATHS)
                .order(0);

        // 2. JWT 鉴权
        registry.addInterceptor(jwtAuthInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns(JWT_EXCLUDE)
                .order(10);

        // 3. RBAC 角色权限
        registry.addInterceptor(permissionInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns(JWT_EXCLUDE)
                .order(20);
    }
}
