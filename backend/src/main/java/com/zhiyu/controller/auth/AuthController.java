package com.zhiyu.controller.auth;

import com.zhiyu.common.R;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.service.AuthService;
import com.zhiyu.service.SmsCodeService;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.service.dto.ProfileUpdateDTO;
import com.zhiyu.service.dto.RefreshTokenRequest;
import com.zhiyu.service.dto.RegisterRequest;
import com.zhiyu.service.dto.SmsCodeRequest;
import com.zhiyu.service.dto.SmsLoginRequest;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.RegistrationResponse;
import com.zhiyu.vo.SmsCodeResponse;
import com.zhiyu.vo.UserInfoVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 认证接口（PRD 9.1）
 * /api/v1/auth/login   POST 登录
 * /api/v1/auth/refresh POST 刷新token
 * /api/v1/auth/me      GET  当前用户信息
 * /api/v1/auth/logout  POST 登出
 */
@Tag(name = "认证")
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final SmsCodeService smsCodeService;

    @Operation(summary = "手机号验证注册学生或教师账号")
    @PostMapping("/register")
    public R<RegistrationResponse> register(@Valid @RequestBody RegisterRequest req) {
        return R.ok(authService.register(req));
    }

    @Operation(summary = "登录，返回 JWT")
    @PostMapping("/login")
    public R<LoginResponse> login(@Valid @RequestBody LoginRequest req) {
        return R.ok(authService.login(req));
    }

    @Operation(summary = "账号密码登录（Mobile 明确路径）")
    @PostMapping("/login/password")
    public R<LoginResponse> passwordLogin(@Valid @RequestBody LoginRequest req) {
        return R.ok(authService.login(req));
    }

    @Operation(summary = "获取手机登录验证码")
    @PostMapping("/sms-code")
    public R<SmsCodeResponse> smsCode(@Valid @RequestBody SmsCodeRequest req) {
        return R.ok(smsCodeService.sendCode(req.getPhone()));
    }

    @Operation(summary = "手机号验证码登录")
    @PostMapping("/login/sms")
    public R<LoginResponse> smsLogin(@Valid @RequestBody SmsLoginRequest req) {
        return R.ok(authService.smsLogin(req));
    }

    @Operation(summary = "刷新 token")
    @PostMapping("/refresh")
    public R<LoginResponse> refresh(@Valid @RequestBody RefreshTokenRequest req) {
        return R.ok(authService.refresh(req.getRefreshToken()));
    }

    @Operation(summary = "获取当前登录用户信息")
    @GetMapping("/me")
    public R<UserInfoVO> me() {
        return R.ok(authService.currentUser(UserContext.requireUserId()));
    }

    @Operation(summary = "更新当前用户个人资料")
    @PutMapping("/me")
    public R<UserInfoVO> updateProfile(@RequestBody ProfileUpdateDTO dto) {
        return R.ok(authService.updateProfile(UserContext.requireUserId(), dto));
    }

    @Operation(summary = "登出（客户端清除 token 即可，服务端黑名单见 P2）")
    @PostMapping("/logout")
    public R<Void> logout() {
        UserContext.clear();
        return R.ok();
    }
}
