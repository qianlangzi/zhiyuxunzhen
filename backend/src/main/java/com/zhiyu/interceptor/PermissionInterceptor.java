package com.zhiyu.interceptor;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * RBAC 权限拦截器（PRD 10.3 / 3.1）
 * 基于请求路径前缀与角色匹配：
 *   /api/v1/admin/**   → 角色 4(管理员) 5(运维)
 *   /api/v1/teacher/** → 角色 1(教师)，且需 audit_status=2
 *   /api/v1/student/** → 角色 0(学生)
 * 数据级权限（教师只能看授权班级、学生只能看本人数据）由 Service 层校验
 */
@Component
public class PermissionInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse resp, Object handler) {
        UserContext.LoginUser user = UserContext.get();
        if (user == null) {
            // 未登录请求由 JwtAuthInterceptor 拦截，此处放行让其走正常流程
            return true;
        }
        String uri = req.getRequestURI();
        Integer role = user.getRole();

        if (uri.startsWith("/api/v1/admin/")) {
            if (role == null || (role != 4 && role != 5)) {
                throw new BizException(ResultCode.FORBIDDEN);
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
