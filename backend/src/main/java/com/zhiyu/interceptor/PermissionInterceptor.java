package com.zhiyu.interceptor;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.util.UrlPathHelper;

/**
 * RBAC 权限拦截器（PRD 10.3 / 3.1）
 * 基于请求路径前缀 + 端点精确匹配与角色校验：
 *   /api/v1/admin/users/import (POST) → 角色 2(教学秘书) 4(管理员)
 *   /api/v1/admin/dashboard (GET)     → 角色 3(教研室主任) 4(管理员) 5(运维)
 *   /api/v1/admin/** (其余)           → 角色 4(管理员)
 *   /api/v1/teacher/**                → 角色 1(教师)，且需 audit_status=2
 *   /api/v1/student/**                → 角色 0(学生)
 * 数据级权限（教师只能看授权班级、学生只能看本人数据）由 Service 层校验
 *
 * 路径获取：使用 UrlPathHelper.getPathWithinApplication() 而非 getRequestURI()，
 * 自动去除 context-path 前缀，避免未来配置 server.servlet.context-path 后路径失配。
 */
@Component
public class PermissionInterceptor implements HandlerInterceptor {

    /** 用于获取去除 context-path 的应用内路径，兼容 context-path 变更 */
    private static final UrlPathHelper PATH_HELPER = new UrlPathHelper();

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse resp, Object handler) {
        UserContext.LoginUser user = UserContext.get();
        if (user == null) {
            // 未登录请求由 JwtAuthInterceptor 拦截，此处放行让其走正常流程
            return true;
        }
        // 使用应用内路径（去除 context-path），避免 context-path 变更导致 RBAC 失配
        String uri = PATH_HELPER.getPathWithinApplication(req);
        Integer role = user.getRole();

        if (uri.startsWith("/api/v1/admin/")) {
            if (role == null) {
                throw new BizException(ResultCode.FORBIDDEN);
            }
            String method = req.getMethod();
            // 精确端点角色矩阵（PRD 3.1 最小权限，P0 阶段）：
            //   POST /admin/users/import → 教学秘书(2)、管理员(4)
            //   GET  /admin/dashboard    → 教研室主任(3)、管理员(4)、运维(5)
            //   其余 /admin/**            → 仅管理员(4)
            // role 5 的模型配置/系统日志待后端支持白名单后开放；role 3 的审批流程待接口实现
            if ("POST".equalsIgnoreCase(method) && "/api/v1/admin/users/import".equals(uri)) {
                if (role != 2 && role != 4) {
                    throw new BizException(ResultCode.FORBIDDEN);
                }
            } else if ("GET".equalsIgnoreCase(method) && "/api/v1/admin/dashboard".equals(uri)) {
                if (role != 3 && role != 4 && role != 5) {
                    throw new BizException(ResultCode.FORBIDDEN);
                }
            } else {
                if (role != 4) {
                    throw new BizException(ResultCode.FORBIDDEN);
                }
            }
        } else if (uri.startsWith("/api/v1/teacher/")) {
            if (role == null || role != 1) {
                throw new BizException(ResultCode.FORBIDDEN);
            }
            // 教师需资质审核通过才能操作写接口（GET 预览/试诊放宽）
            Integer audit = user.getAuditStatus();
            boolean isWrite = !"GET".equalsIgnoreCase(req.getMethod());
            // 例外：资质认证提交接口允许未审核教师调用（PRD 9.1）
            boolean isAuditSubmit = "/api/v1/teacher/profile/audit-submit".equals(uri);
            if (isWrite && !isAuditSubmit && (audit == null || audit != 2)) {
                throw new BizException(ResultCode.TEACHER_NOT_AUDITED);
            }
        } else if (uri.startsWith("/api/v1/student/")) {
            if (role == null || role != 0) {
                throw new BizException(ResultCode.FORBIDDEN);
            }
        }
        return true;
    }
}
