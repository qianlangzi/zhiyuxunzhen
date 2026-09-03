package com.zhiyu.config;

import com.zhiyu.interceptor.InternalApiInterceptor;
import com.zhiyu.interceptor.JwtAuthInterceptor;
import com.zhiyu.interceptor.MustChangePasswordInterceptor;
import com.zhiyu.interceptor.PermissionInterceptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web MVC 配置（PRD 16.3.1）：注册拦截器链
 * 顺序：InternalApiInterceptor(0) → JwtAuthInterceptor(10) → MustChangePasswordInterceptor(15) → PermissionInterceptor(20)
 */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    @Autowired
    private JwtAuthInterceptor jwtAuthInterceptor;

    @Autowired
    private MustChangePasswordInterceptor mustChangePasswordInterceptor;

    @Autowired
    private PermissionInterceptor permissionInterceptor;

    @Autowired
    private InternalApiInterceptor internalApiInterceptor;

    @Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    /** 不需要 JWT 鉴权的路径 */
    private static final String[] JWT_EXCLUDE = {
            "/api/v1/auth/login",
            "/api/v1/auth/login/**",
            "/api/v1/auth/register",
            "/api/v1/auth/sms-code",
            "/api/v1/auth/captcha/**",
            "/api/v1/auth/upload",
            "/api/v1/auth/refresh",
            "/api/v1/auth/reset-password",
            "/api/v1/health",
            "/api/internal/**",
            "/swagger-ui/**",
            "/swagger-ui.html",
            "/v3/api-docs/**",
            "/actuator/**",
            "/error",
            "/uploads/**"
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

        // 3. 强制改密安全边界：以 DB must_change_password 为准，
        //    仅放行 password/me/logout/refresh，阻止未改密账号调用业务接口（Issue1 P0）
        registry.addInterceptor(mustChangePasswordInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns(JWT_EXCLUDE)
                .order(15);

        // 4. RBAC 角色权限
        registry.addInterceptor(permissionInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns(JWT_EXCLUDE)
                .order(20);
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 上传的证书图片以静态资源方式暴露访问
        String location = uploadDir.endsWith("/") ? uploadDir : uploadDir + "/";
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations("file:" + location);
    }
}
