package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.AuthService;
import com.zhiyu.service.SmsCodeService;
import com.zhiyu.service.dto.ChangePasswordRequest;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.service.dto.ProfileUpdateDTO;
import com.zhiyu.service.dto.RegisterRequest;
import com.zhiyu.service.dto.SmsLoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.RegistrationResponse;
import com.zhiyu.vo.UserInfoVO;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;

/**
 * 认证服务实现（PRD 9.1 / 10.3）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final SysUserMapper userMapper;
    private final JwtUtils jwtUtils;
    private final PasswordEncoder passwordEncoder;
    private final SmsCodeService smsCodeService;
    private final AuditLogService auditLogService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public RegistrationResponse register(RegisterRequest req) {
        String username = req.getUsername().trim();
        String phone = req.getPhone().trim();
        String realName = req.getRealName().trim();
        if (realName.length() < 2) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "姓名长度须为 2-50 位");
        }
        ensureRegistrationAvailable(username, phone);

        boolean teacher = req.getRole() == 1;

        // 学校必填（学生与教师）
        if (!StringUtils.hasText(req.getSchoolName())) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "学校不能为空");
        }

        if (teacher) {
            // 教师：资质编号、科室、证书图片必填
            if (!StringUtils.hasText(req.getCertificateNo())
                    || !StringUtils.hasText(req.getDepartment())
                    || !StringUtils.hasText(req.getTeacherCertificateImage())) {
                throw new BizException(ResultCode.VALIDATION_FAILED,
                        "教师注册必须填写资质编号、所属科室并上传资质证书");
            }
        } else {
            // 学生：年级、班级必填
            if (!StringUtils.hasText(req.getGrade()) || !StringUtils.hasText(req.getClassName())) {
                throw new BizException(ResultCode.VALIDATION_FAILED,
                        "学生注册必须填写年级和班级");
            }
        }

        smsCodeService.verifyAndConsume(phone, req.getCode());

        SysUser user = new SysUser();
        user.setUsername(username);
        user.setPasswordHash(passwordEncoder.encode(req.getPassword()));
        user.setRealName(realName);
        user.setPhone(phone);
        user.setRole(req.getRole());
        user.setAuditStatus(teacher ? 1 : 0);
        user.setStatus(0);
        user.setIsDeleted(0);
        user.setSchoolName(req.getSchoolName().trim());
        if (teacher) {
            user.setTeacherCertificateNo(req.getCertificateNo().trim());
            user.setDepartment(req.getDepartment().trim());
            user.setTeacherCertificateImage(req.getTeacherCertificateImage().trim());
        } else {
            user.setGrade(req.getGrade().trim());
            user.setClassName(req.getClassName().trim());
        }

        try {
            userMapper.insert(user);
        } catch (DuplicateKeyException e) {
            ensureRegistrationAvailable(username, phone);
            throw e;
        }

        log.info("用户注册成功: {} (role={})", username, req.getRole());

        // 学生注册即视为可用，直接发放 access+refresh token 免二次登录；教师需人工审核，不发放。
        // 凭证成对发放且必须携带 credentialVersion（与登录签发逻辑一致），
        // 否则注册发放的 token 会被凭证版本校验拒绝（或绕过版本防护）。
        String token = null;
        String refreshToken = null;
        if (!teacher) {
            Integer credentialVersion = user.getCredentialVersion() == null
                    ? 0 : user.getCredentialVersion();
            Integer auditStatus = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
            token = jwtUtils.issueToken(user.getId(), username, user.getRole(),
                    auditStatus, credentialVersion);
            refreshToken = jwtUtils.issueRefreshToken(user.getId(), credentialVersion);
        }
        return RegistrationResponse.builder()
                .userId(user.getId())
                .username(username)
                .realName(realName)
                .role(req.getRole())
                .auditStatus(user.getAuditStatus())
                .token(token)
                .refreshToken(refreshToken)
                .message(teacher
                        ? "教师注册申请已提交，请等待管理员审核后登录"
                        : "注册成功")
                .build();
    }

    private void ensureRegistrationAvailable(String username, String phone) {
        Long usernameCount = userMapper.selectCount(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getUsername, username));
        if (usernameCount != null && usernameCount > 0) {
            throw new BizException(ResultCode.USERNAME_EXISTS);
        }
        Long phoneCount = userMapper.selectCount(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getPhone, phone));
        if (phoneCount != null && phoneCount > 0) {
            throw new BizException(ResultCode.PHONE_EXISTS);
        }
    }

    @Override
    public LoginResponse login(LoginRequest req) {
        String identifier = req.getUsername() == null ? "" : req.getUsername().trim();
        SysUser user = userMapper.selectOne(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getUsername, identifier));
        // 支持手机号登录：非用户名时按手机号再查一次
        if (user == null && isPhone(identifier)) {
            user = userMapper.selectOne(
                    new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<SysUser>()
                            .eq(SysUser::getPhone, identifier));
        }
        if (user == null) {
            log.warn("登录失败，用户不存在: {}", identifier);
            throw new BizException(ResultCode.USERNAME_OR_PASSWORD_ERROR);
        }
        if (!passwordEncoder.matches(req.getPassword(), user.getPasswordHash())) {
            log.warn("登录失败，密码错误: {}", identifier);
            throw new BizException(ResultCode.USERNAME_OR_PASSWORD_ERROR);
        }
        return issueLogin(user);
    }

    /** 判断是否为合法的 11 位手机号（用于账号/手机号二合一登录） */
    private boolean isPhone(String str) {
        return str != null && str.matches("^1[3-9]\\d{9}$");
    }

    @Override
    public LoginResponse smsLogin(SmsLoginRequest req) {
        smsCodeService.verifyAndConsume(req.getPhone(), req.getCode());
        SysUser user = userMapper.selectOne(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getPhone, req.getPhone()));
        if (user == null) {
            log.warn("短信登录失败，手机号未绑定用户: {}", maskPhone(req.getPhone()));
            throw new BizException(ResultCode.PHONE_OR_CODE_ERROR);
        }
        return issueLogin(user);
    }

    private LoginResponse issueLogin(SysUser user) {
        if (user.getStatus() != null && user.getStatus() == 1) {
            throw new BizException(ResultCode.ACCOUNT_FROZEN);
        }
        if (user.getRole() != null && user.getRole() == 1) {
            int auditStatus = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
            if (auditStatus == 1) {
                throw new BizException(ResultCode.TEACHER_AUDIT_PENDING);
            }
            // P1-2 修复：允许被驳回教师（auditStatus=3）登录，以便重新提交资质材料。
            // MustChangePasswordInterceptor 会限制被驳回教师仅能访问 /auth/me、/auth/password、
            // /auth/logout、/auth/refresh 和 /teacher/profile/audit-submit，其余端点一律拒绝。
            // 旧实现拒绝 auditStatus=3 登录 → 教师无法获取 token → 无法调用 submitAudit → 死锁。
        }

        updateLastLogin(user.getId());

        Integer auditStatus = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
        Integer credentialVersion = user.getCredentialVersion() == null ? 0 : user.getCredentialVersion();
        String token = jwtUtils.issueToken(user.getId(), user.getUsername(), user.getRole(), auditStatus, credentialVersion);
        String refresh = jwtUtils.issueRefreshToken(user.getId(), credentialVersion);

        log.info("用户登录成功: {} (role={})", user.getUsername(), user.getRole());
        return LoginResponse.builder()
                .token(token)
                .refreshToken(refresh)
                .expiresIn(jwtUtils.getAccessExpireMs() / 1000)
                .userId(user.getId())
                .username(user.getUsername())
                .realName(user.getRealName())
                .role(user.getRole())
                .auditStatus(auditStatus)
                .mustChangePassword(user.getMustChangePassword() != null && user.getMustChangePassword())
                .build();
    }

    @Override
    public LoginResponse refresh(String refreshToken) {
        try {
            Claims claims = jwtUtils.parseToken(refreshToken);
            if (!"refresh".equals(claims.get("type", String.class))) {
                throw new BizException(ResultCode.UNAUTHORIZED, "无效的refresh token");
            }
            Long userId = Long.valueOf(claims.getSubject());
            SysUser user = userMapper.selectById(userId);
            if (user == null) {
                throw new BizException(ResultCode.UNAUTHORIZED);
            }
            if (user.getStatus() != null && user.getStatus() == 1) {
                throw new BizException(ResultCode.ACCOUNT_FROZEN);
            }

            // 凭证版本校验：refresh token 中的版本必须与 DB 一致
            // 改密后版本递增，旧 refresh token 版本不匹配 → 拒绝（撤销旧 refresh 凭证）
            Integer tokenVersion = claims.get("credentialVersion", Integer.class);
            Integer dbVersion = user.getCredentialVersion() == null ? 0 : user.getCredentialVersion();
            if (tokenVersion == null || !tokenVersion.equals(dbVersion)) {
                log.debug("refresh token 凭证版本不匹配: token={} db={} userId={}", tokenVersion, dbVersion, userId);
                throw new BizException(ResultCode.UNAUTHORIZED, "凭证已失效，请重新登录");
            }

            Integer auditStatus = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
            String newToken = jwtUtils.issueToken(user.getId(), user.getUsername(), user.getRole(), auditStatus, dbVersion);
            String newRefresh = jwtUtils.issueRefreshToken(user.getId(), dbVersion);
            return LoginResponse.builder()
                    .token(newToken)
                    .refreshToken(newRefresh)
                    .expiresIn(jwtUtils.getAccessExpireMs() / 1000)
                    .userId(user.getId())
                    .username(user.getUsername())
                    .realName(user.getRealName())
                    .role(user.getRole())
                    .auditStatus(auditStatus)
                    // refresh 响应必须带回最新 mustChangePassword，否则前端刷新 token 后
                    // 会丢失强制改密状态（Issue1 P0：与 MustChangePasswordInterceptor 的 DB 状态保持一致）
                    .mustChangePassword(user.getMustChangePassword() != null && user.getMustChangePassword())
                    .build();
        } catch (JwtException e) {
            throw new BizException(ResultCode.TOKEN_EXPIRED, "refresh token 已过期，请重新登录");
        }
    }

    @Override
    public UserInfoVO currentUser(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        return UserInfoVO.builder()
                .id(user.getId())
                .username(user.getUsername())
                .realName(user.getRealName())
                .role(user.getRole())
                .classId(user.getClassId())
                .auditStatus(user.getAuditStatus())
                .status(user.getStatus())
                .phone(maskPhone(user.getPhone()))
                .avatar(user.getAvatar())
                .authorizedClasses(user.getAuthorizedClasses())
                .lastLoginAt(user.getLastLoginAt())
                .mustChangePassword(user.getMustChangePassword() != null && user.getMustChangePassword())
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public UserInfoVO updateProfile(Long userId, ProfileUpdateDTO dto) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }

        // P0-4 修复：使用窄字段 UpdateWrapper 只更新 avatar 列。
        // updateById(user) 会写入完整实体快照，并发场景下可能把另一个事务已递增的
        // credential_version 或修改的 role/status/passwordHash 写回旧值，导致撤销被回滚。
        if (dto.getAvatarPath() != null) {
            userMapper.update(null,
                    new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                            .eq("id", userId)
                            .set("avatar", dto.getAvatarPath()));
        }

        // 返回更新后的用户信息
        return currentUser(userId);
    }

    @Override
    public void updateLastLogin(Long userId) {
        SysUser update = new SysUser();
        update.setId(userId);
        update.setLastLoginAt(LocalDateTime.now());
        userMapper.updateById(update);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public LoginResponse changePassword(Long userId, ChangePasswordRequest req) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        // 校验原密码，防止会话被劫持后恶意改密
        if (!passwordEncoder.matches(req.getOldPassword(), user.getPasswordHash())) {
            log.warn("修改密码失败，原密码错误: userId={}", userId);
            throw new BizException(ResultCode.VALIDATION_FAILED, "原密码不正确");
        }
        // 新密码不能与原密码相同
        if (passwordEncoder.matches(req.getNewPassword(), user.getPasswordHash())) {
            throw new BizException(ResultCode.PASSWORD_SAME_AS_OLD);
        }

        // CAS 更新：条件为 id + status=0(未冻结) + 旧 passwordHash + token 中的 credentialVersion
        //
        // P0-1 修复（冻结账号可通过在途改密复活）：
        //   1. **使用 token 中的版本，而非 DB 重读版本**：若管理员在用户请求期间冻结账号
        //      （递增 version v→v+1），token 中的版本仍是 v，CAS .eq("credential_version", v)
        //      不匹配 DB 的 v+1 → 失败。若用 DB 重读版本，CAS 读到 v+1 并成功，等于冻结后被改密复活。
        //   2. **加 status=0 条件**：即使版本匹配，冻结中的账号（status=1）也不允许改密。
        //      双保险：版本 CAS 防并发交错，status CAS 防冻结后改密。
        //   3. 拦截器侧（MustChangePasswordInterceptor）同步增加冻结状态检查。
        //
        // 同时递增 credentialVersion，使旧 token（旧版本）立即失效。
        // 使用 UpdateWrapper（列名字符串）而非 LambdaUpdateWrapper，避免 lambda cache NPE。
        Integer tokenVersion = UserContext.get().getCredentialVersion();
        Integer oldVersion = tokenVersion == null ? 0 : tokenVersion;
        int newVersion = oldVersion + 1;
        com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser> casWrapper =
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("status", 0)
                        .eq("password_hash", user.getPasswordHash())
                        .eq("credential_version", oldVersion)
                        .set("password_hash", passwordEncoder.encode(req.getNewPassword()))
                        .set("must_change_password", false)
                        .set("credential_version", newVersion);
        int rows = userMapper.update(null, casWrapper);
        if (rows == 0) {
            // CAS 失败：密码已变 / 凭证版本已变 / 账号已被冻结
            log.warn("CAS 更新失败: userId={} tokenVersion={} (可能已被冻结/改密/角色变更)", userId, oldVersion);
            throw new BizException(ResultCode.VALIDATION_FAILED, "原密码不正确或凭证已变更，请重新登录后重试");
        }

        // 审计日志：不记录密码明文，仅记录操作与目标用户
        auditLogService.record("change_password", "user", userId, null,
                "{\"mustChangePassword\":false,\"credentialVersion\":" + newVersion + "}");

        log.info("用户修改密码成功: userId={} newVersion={}", userId, newVersion);

        // 签发新 token（携带递增后的 credentialVersion），客户端用新 token 替换旧 token
        // 旧 token 因版本不匹配被 MustChangePasswordInterceptor 拒绝
        Integer auditStatus = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
        String newToken = jwtUtils.issueToken(user.getId(), user.getUsername(), user.getRole(), auditStatus, newVersion);
        String newRefresh = jwtUtils.issueRefreshToken(user.getId(), newVersion);
        return LoginResponse.builder()
                .token(newToken)
                .refreshToken(newRefresh)
                .expiresIn(jwtUtils.getAccessExpireMs() / 1000)
                .userId(user.getId())
                .username(user.getUsername())
                .realName(user.getRealName())
                .role(user.getRole())
                .auditStatus(auditStatus)
                .mustChangePassword(false)
                .build();
    }

    /** 手机号脱敏（PRD 10.3） */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }
}
