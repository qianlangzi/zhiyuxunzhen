package com.zhiyu.interceptor;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.util.UrlPathHelper;

/**
 * 强制改密安全边界拦截器（PRD 10.3 / Issue1 P0）
 *
 * <p>以数据库 {@code sys_user.must_change_password} 字段为准（不信任 JWT 或客户端状态），
 * 阻止未完成首次改密的用户（导入学生）调用任何业务接口，避免拿临时密码登录取得 JWT 后
 * 直接调用 /api/v1/student/** 绕过 App 强制改密流程。</p>
 *
 * <p>同时校验凭证版本（credentialVersion）：JWT 中携带的版本必须与 DB 一致，
 * 否则视为旧凭证已被撤销（改密后递增版本使旧 token 立即失效）。</p>
 *
 * <p>放行白名单（方法 + 路径精确匹配）：
 * <ul>
 *   <li>PUT  /api/v1/auth/password — 改密本身（改密接口用旧 token，版本仍匹配）</li>
 *   <li>GET  /api/v1/auth/me       — 让前端读取当前状态</li>
 *   <li>POST /api/v1/auth/logout   — 允许退出登录</li>
 *   <li>POST /api/v1/auth/refresh  — 刷新 token（refresh 内部校验版本，不经过此拦截器）</li>
 * </ul>
 *
 * <p>校验顺序（安全边界）：先查库 → 校验凭证版本（旧 token 被拒绝，即使访问白名单端点）
 * → 校验冻结状态（冻结账号仅允许登出，其余 fail-closed）→ 白名单仅绕过 mustChangePassword 校验
 * → mustChangePassword 校验。
 * 不能把白名单放在版本校验之前，否则改密后旧 token 仍能访问 /auth/me 等端点。
 * 不能把白名单放在冻结校验之前，否则冻结账号仍能改密/刷新 token 复活会话。
 *
 * <p>注册顺序：order=15，位于 JwtAuthInterceptor(10) 之后、PermissionInterceptor(20) 之前，
 * 确保已解析出 UserContext 再查库校验。</p>
 *
 * <p>设计说明：mustChangePassword 不放入 JWT。若放入 JWT，改密成功后旧 access token 中的
 * true 会继续阻塞直到 token 过期；改为以 DB 为准后，changePassword 服务一旦置 false，
 * 后续任意请求立即放行。但仅此一项不足以撤销旧 token——攻击者持有的旧 token 会因
 * mustChangePassword=false 而获得完整权限。因此引入 credentialVersion：改密时递增版本，
 * 旧 token 携带的旧版本与本拦截器的 DB 版本比较时不匹配，被拒绝。</p>
 */
@Slf4j
@Component
public class MustChangePasswordInterceptor implements HandlerInterceptor {

    @Autowired
    private SysUserMapper userMapper;

    private static final UrlPathHelper PATH_HELPER = new UrlPathHelper();

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse resp, Object handler) {
        // 未登录请求由 JwtAuthInterceptor 拦截，此处无需处理
        UserContext.LoginUser user = UserContext.get();
        if (user == null) {
            return true;
        }

        String uri = PATH_HELPER.getPathWithinApplication(req);
        String method = req.getMethod();

        // 以数据库状态为准，避免 JWT 过期前携带陈旧标记阻塞用户
        SysUser entity = userMapper.selectById(user.getUserId());
        if (entity == null) {
            // 用户已被删除：按未登录处理，由后续 RBAC 拦截或前端清理会话
            throw new BizException(ResultCode.UNAUTHORIZED, "用户不存在");
        }

        // 凭证版本校验（必须在白名单之前）：改密后递增版本，旧 token 版本不匹配 → 拒绝
        // 不能把白名单放前面——否则改密后旧 token 仍能访问 /auth/me、/auth/logout 等白名单端点
        Integer tokenVersion = user.getCredentialVersion();
        Integer dbVersion = entity.getCredentialVersion();
        if (tokenVersion == null || dbVersion == null || !tokenVersion.equals(dbVersion)) {
            log.debug("凭证版本不匹配: token={} db={} userId={}", tokenVersion, dbVersion, user.getUserId());
            throw new BizException(ResultCode.UNAUTHORIZED, "凭证已失效，请重新登录");
        }

        // P0-1 修复：冻结状态检查（fail-closed）
        // 即使 token 版本匹配（管理员冻结时可能未递增版本，或版本递增前的在途 token
        // 恰好通过版本校验），冻结状态的账号也必须被拦截。
        // 仅允许 POST /api/v1/auth/logout（让用户能清除本地会话），其余端点一律拒绝。
        // 这堵住了「冻结后改密复活」链路的最后一环：即使攻击者通过某种方式获得新 token，
        // 拦截器仍因 status=1 拒绝所有业务请求。
        if (entity.getStatus() != null && entity.getStatus() == 1) {
            if ("POST".equalsIgnoreCase(method) && "/api/v1/auth/logout".equals(uri)) {
                log.debug("冻结账号登出: userId={}", user.getUserId());
                return true;
            }
            log.debug("账号已被冻结: userId={} uri={} method={}", user.getUserId(), uri, method);
            throw new BizException(ResultCode.ACCOUNT_FROZEN, "账号已被冻结，请联系管理员");
        }

        // 白名单：改密 / 查当前用户 / 登出 / 刷新 token 仅绕过 mustChangePassword 校验
        // 注意：版本校验 + 冻结校验已在上方完成，旧 token 和冻结账号到不了这里
        if (isWhitelisted(method, uri)) {
            return true;
        }

        // mustChangePassword 校验：fail-closed，null 视为需要改密（安全边界不信任 null）
        Boolean mustChange = entity.getMustChangePassword();
        if (mustChange == null || mustChange) {
            // 严格拒绝：仅允许改密相关端点，防止业务数据被未改密账号访问
            throw new BizException(ResultCode.PASSWORD_CHANGE_REQUIRED);
        }
        return true;
    }

    /** 精确匹配放行端点（方法 + 路径） */
    private boolean isWhitelisted(String method, String uri) {
        if (uri == null || method == null) {
            return false;
        }
        return ("PUT".equalsIgnoreCase(method) && "/api/v1/auth/password".equals(uri))
                || ("GET".equalsIgnoreCase(method) && "/api/v1/auth/me".equals(uri))
                || ("POST".equalsIgnoreCase(method) && "/api/v1/auth/logout".equals(uri))
                || ("POST".equalsIgnoreCase(method) && "/api/v1/auth/refresh".equals(uri));
    }
}
