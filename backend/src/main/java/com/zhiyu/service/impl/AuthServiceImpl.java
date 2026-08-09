package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
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
        return RegistrationResponse.builder()
                .userId(user.getId())
                .username(username)
                .role(req.getRole())
                .auditStatus(user.getAuditStatus())
                .message(teacher
                        ? "教师注册申请已提交，请等待管理员审核后登录"
                        : "注册成功，请使用新账号登录")
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
        SysUser user = userMapper.selectOne(
                new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getUsername, req.getUsername()));
        if (user == null) {
            log.warn("登录失败，用户不存在: {}", req.getUsername());
            throw new BizException(ResultCode.USERNAME_OR_PASSWORD_ERROR);
        }
        if (!passwordEncoder.matches(req.getPassword(), user.getPasswordHash())) {
            log.warn("登录失败，密码错误: {}", req.getUsername());
            throw new BizException(ResultCode.USERNAME_OR_PASSWORD_ERROR);
        }
        return issueLogin(user);
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
            if (auditStatus == 3) {
                throw new BizException(ResultCode.TEACHER_AUDIT_REJECTED);
            }
        }

        updateLastLogin(user.getId());

        Integer auditStatus = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
        String token = jwtUtils.issueToken(user.getId(), user.getUsername(), user.getRole(), auditStatus);
        String refresh = jwtUtils.issueRefreshToken(user.getId());

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
            Integer auditStatus = user.getAuditStatus() == null ? 0 : user.getAuditStatus();
            String newToken = jwtUtils.issueToken(user.getId(), user.getUsername(), user.getRole(), auditStatus);
            String newRefresh = jwtUtils.issueRefreshToken(user.getId());
            return LoginResponse.builder()
                    .token(newToken)
                    .refreshToken(newRefresh)
                    .expiresIn(jwtUtils.getAccessExpireMs() / 1000)
                    .userId(user.getId())
                    .username(user.getUsername())
                    .realName(user.getRealName())
                    .role(user.getRole())
                    .auditStatus(auditStatus)
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

        // 更新可修改的字段
        if (dto.getAvatarPath() != null) {
            user.setAvatar(dto.getAvatarPath());
        }

        userMapper.updateById(user);

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
    public void changePassword(Long userId, ChangePasswordRequest req) {
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

        // 仅更新密码哈希与强制改密标志，避免覆盖其他字段
        SysUser update = new SysUser();
        update.setId(userId);
        update.setPasswordHash(passwordEncoder.encode(req.getNewPassword()));
        update.setMustChangePassword(false);
        userMapper.updateById(update);

        // 审计日志：不记录密码明文，仅记录操作与目标用户
        auditLogService.record("change_password", "user", userId, null,
                "{\"mustChangePassword\":false}");

        log.info("用户修改密码成功: userId={}", userId);
    }

    /** 手机号脱敏（PRD 10.3） */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }
}
