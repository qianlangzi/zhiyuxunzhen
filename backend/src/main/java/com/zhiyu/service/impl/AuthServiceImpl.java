package com.zhiyu.service.impl;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.AuthService;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.UserInfoVO;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

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
        if (user.getStatus() != null && user.getStatus() == 1) {
            throw new BizException(ResultCode.ACCOUNT_FROZEN);
        }
        // 管理端角色(2-5)不允许从 App 登录
        if (user.getRole() != null && user.getRole() >= 2) {
            log.info("管理端用户尝试 App 登录: {}", req.getUsername());
            throw new BizException(ResultCode.FORBIDDEN, "请使用 Web 管理端登录");
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
                .build();
    }

    @Override
    public void updateLastLogin(Long userId) {
        SysUser update = new SysUser();
        update.setId(userId);
        update.setLastLoginAt(LocalDateTime.now());
        userMapper.updateById(update);
    }

    /** 手机号脱敏（PRD 10.3） */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }
}
