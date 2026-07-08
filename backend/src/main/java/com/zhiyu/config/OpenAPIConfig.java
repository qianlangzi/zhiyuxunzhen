package com.zhiyu.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI 3 文档配置（PRD 16.3.2）
 * 访问路径：/swagger-ui.html （UI） / /v3/api-docs （JSON）
 */
@Configuration
public class OpenAPIConfig {

    private static final String SECURITY_SCHEME_NAME = "bearerAuth";

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("智愈寻真 · 内科教研协同智能体平台 API")
                        .description("医疗教育 AI 训练平台后端接口文档 V2.1\n\n"
                                + "## 角色体系\n"
                                + "- 0 学生 / 1 教师 / 2 教学秘书 / 3 教研室主任 / 4 管理员 / 5 运维\n\n"
                                + "## 鉴权\n"
                                + "除 /api/v1/auth/login、/api/v1/health、/api/internal/** 外，所有接口需在 Header 中携带 `Authorization: Bearer <JWT>`\n\n"
                                + "## 错误码\n"
                                + "- 0 成功\n"
                                + "- 1xxx 客户端错误（1001 未登录 / 1003 无权限 / 1422 参数校验失败）\n"
                                + "- 2xxx 业务错误（2001 账号密码错误 / 2101 病例不存在 / 2106 重复提交 等）\n"
                                + "- 5xxx 服务端错误")
                        .version("V2.1")
                        .contact(new Contact().name("智愈寻真研发团队"))
                        .license(new License().name("Proprietary")))
                .addSecurityItem(new SecurityRequirement().addList(SECURITY_SCHEME_NAME))
                .components(new Components()
                        .addSecuritySchemes(SECURITY_SCHEME_NAME,
                                new SecurityScheme()
                                        .name(SECURITY_SCHEME_NAME)
                                        .type(SecurityScheme.Type.HTTP)
                                        .scheme("bearer")
                                        .bearerFormat("JWT")
                                        .in(SecurityScheme.In.HEADER)
                                        .description("JWT Bearer Token 鉴权")));
    }
}
