package com.zhiyu.common.context;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

/**
 * 请求级用户上下文（ThreadLocal），由 JwtAuthInterceptor 注入、请求结束后清理
 */
public class UserContext {

    @Data
    @Builder
    @AllArgsConstructor
    public static class LoginUser {
        private Long userId;
        private String username;
        private Integer role;          // 0学生 1教师 2教学秘书 3教研室主任 4管理员 5运维
        private Integer auditStatus;   // 教师认证状态：0未提交 1待审核 2通过 3驳回
        private Integer credentialVersion; // 凭证版本：与 DB 比较，不匹配则拒绝（撤销旧 token）
    }

    private static final ThreadLocal<LoginUser> HOLDER = new ThreadLocal<>();

    public static void set(LoginUser user) {
        HOLDER.set(user);
    }

    public static LoginUser get() {
        return HOLDER.get();
    }

    public static void clear() {
        HOLDER.remove();
    }

    /** 获取当前用户ID，未登录抛异常 */
    public static Long requireUserId() {
        LoginUser u = HOLDER.get();
        if (u == null || u.getUserId() == null) {
            throw new BizException(ResultCode.UNAUTHORIZED);
        }
        return u.getUserId();
    }

    public static LoginUser requireUser() {
        LoginUser u = HOLDER.get();
        if (u == null) {
            throw new BizException(ResultCode.UNAUTHORIZED);
        }
        return u;
    }

    /** 校验当前用户是否为指定角色之一，不满足抛 FORBIDDEN */
    public static void requireRole(int... roles) {
        LoginUser u = requireUser();
        if (u.getRole() == null) {
            throw new BizException(ResultCode.FORBIDDEN);
        }
        for (int r : roles) {
            if (u.getRole() == r) return;
        }
        throw new BizException(ResultCode.FORBIDDEN);
    }

    /** 仅管理员(4)和运维(5) */
    public static void requireAdmin() {
        requireRole(4, 5);
    }
}
