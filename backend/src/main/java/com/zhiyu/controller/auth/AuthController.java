package com.zhiyu.controller.auth;

import com.zhiyu.common.R;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.util.JwtUtils;
import com.zhiyu.service.AuthService;
import com.zhiyu.service.CaptchaService;
import com.zhiyu.service.SmsCodeService;
import com.zhiyu.service.dto.ChangePasswordRequest;
import com.zhiyu.service.dto.LoginRequest;
import com.zhiyu.service.dto.ProfileUpdateDTO;
import com.zhiyu.service.dto.RefreshTokenRequest;
import com.zhiyu.service.dto.RegisterRequest;
import com.zhiyu.service.dto.SmsCodeRequest;
import com.zhiyu.service.dto.SmsLoginRequest;
import com.zhiyu.vo.CaptchaResponse;
import com.zhiyu.vo.LoginResponse;
import com.zhiyu.vo.RegistrationResponse;
import com.zhiyu.vo.SmsCodeResponse;
import com.zhiyu.vo.UserInfoVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

/**
 * 认证接口（PRD 9.1）
 * /api/v1/auth/register POST 注册
 * /api/v1/auth/login    POST 登录
 * /api/v1/auth/refresh  POST 刷新token
 * /api/v1/auth/me       GET  当前用户信息
 * /api/v1/auth/logout   POST 登出
 * /api/v1/auth/captcha  GET  获取图形验证码（防盗刷）
 * /api/v1/auth/upload   POST 上传教师资质证书
 */
@Tag(name = "认证")
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final SmsCodeService smsCodeService;
    private final CaptchaService captchaService;
    private final JwtUtils jwtUtils;

    @Value("${spring.profiles.active:dev}")
    private String activeProfile;

    /** refresh token cookie 名称 */
    private static final String REFRESH_COOKIE_NAME = "zhiyu_refresh";

    @Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    @Value("${zhiyu.upload.base-url:/uploads}")
    private String uploadBaseUrl;

    @Operation(summary = "手机号验证注册学生或教师账号")
    @PostMapping("/register")
    public R<RegistrationResponse> register(@Valid @RequestBody RegisterRequest req) {
        return R.ok(authService.register(req));
    }

    @Operation(summary = "登录，返回 JWT")
    @PostMapping("/login")
    public R<LoginResponse> login(@Valid @RequestBody LoginRequest req,
                                   HttpServletResponse response) {
        LoginResponse loginResponse = authService.login(req);
        setRefreshCookie(response, loginResponse.getRefreshToken());
        // A1 修复：refresh token 只通过 httpOnly cookie 传递，不在 body 中返回，防止 XSS 通过 API 窃取
        loginResponse.setRefreshToken(null);
        return R.ok(loginResponse);
    }

    @Operation(summary = "账号密码登录（Mobile 明确路径）")
    @PostMapping("/login/password")
    public R<LoginResponse> passwordLogin(@Valid @RequestBody LoginRequest req,
                                           HttpServletResponse response) {
        LoginResponse loginResponse = authService.login(req);
        setRefreshCookie(response, loginResponse.getRefreshToken());
        // A1 修复：refresh token 只通过 httpOnly cookie 传递，不在 body 中返回，防止 XSS 通过 API 窃取
        loginResponse.setRefreshToken(null);
        return R.ok(loginResponse);
    }

    @Operation(summary = "获取图形验证码（防盗刷）")
    @GetMapping("/captcha")
    public R<CaptchaResponse> captcha(HttpServletRequest request) {
        return R.ok(captchaService.generate(clientIp(request)));
    }

    @Operation(summary = "获取手机登录验证码")
    @PostMapping("/sms-code")
    public R<SmsCodeResponse> smsCode(@Valid @RequestBody SmsCodeRequest req,
                                      HttpServletRequest request) {
        return R.ok(smsCodeService.sendCode(
                req.getPhone(),
                req.getCaptchaId(),
                req.getCaptchaAnswer(),
                clientIp(request)));
    }

    @Operation(summary = "手机号验证码登录")
    @PostMapping("/login/sms")
    public R<LoginResponse> smsLogin(@Valid @RequestBody SmsLoginRequest req,
                                      HttpServletResponse response) {
        LoginResponse loginResponse = authService.smsLogin(req);
        setRefreshCookie(response, loginResponse.getRefreshToken());
        // A1 修复：refresh token 只通过 httpOnly cookie 传递，不在 body 中返回，防止 XSS 通过 API 窃取
        loginResponse.setRefreshToken(null);
        return R.ok(loginResponse);
    }

    @Operation(summary = "刷新 token")
    @PostMapping("/refresh")
    public R<LoginResponse> refresh(
            @RequestBody(required = false) RefreshTokenRequest req,
            HttpServletRequest request,
            HttpServletResponse response) {
        // A1 修复：优先从 httpOnly cookie 读 refresh token，fallback 到 body（兼容期）
        String refreshToken = extractRefreshTokenFromCookie(request);
        if (refreshToken == null && req != null) {
            refreshToken = req.getRefreshToken();
        }
        if (refreshToken == null) {
            throw new BizException(ResultCode.UNAUTHORIZED, "refresh token 缺失");
        }
        LoginResponse loginResponse = authService.refresh(refreshToken);
        // 轮换 refresh token：设置新 cookie
        setRefreshCookie(response, loginResponse.getRefreshToken());
        // A1 修复：refresh token 只通过 httpOnly cookie 传递，不在 body 中返回，防止 XSS 通过 API 窃取
        loginResponse.setRefreshToken(null);
        return R.ok(loginResponse);
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

    @Operation(summary = "修改密码（首次登录强制改密 / 用户主动改密）")
    @PutMapping("/password")
    public R<LoginResponse> changePassword(@Valid @RequestBody ChangePasswordRequest req,
                                            HttpServletResponse response) {
        // 改密成功后返回新 access/refresh token（携带递增后的 credentialVersion），
        // 客户端必须用新 token 替换旧 token；旧 token 因版本不匹配被 MustChangePasswordInterceptor 拒绝
        LoginResponse loginResponse = authService.changePassword(UserContext.requireUserId(), req);
        setRefreshCookie(response, loginResponse.getRefreshToken());
        // A1 修复：refresh token 只通过 httpOnly cookie 传递，不在 body 中返回，防止 XSS 通过 API 窃取
        loginResponse.setRefreshToken(null);
        return R.ok(loginResponse);
    }

    @Operation(summary = "上传教师资质证书图片（注册时调用）")
    @PostMapping("/upload")
    public R<java.util.Map<String, String>> upload(@RequestParam("file") MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "文件不能为空");
        }
        long maxBytes = 5 * 1024 * 1024; // 5MB
        if (file.getSize() > maxBytes) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "文件大小不能超过 5MB");
        }
        String origName = file.getOriginalFilename();
        String ext = "";
        if (origName != null && origName.contains(".")) {
            ext = origName.substring(origName.lastIndexOf('.')).toLowerCase();
        }
        // 仅允许 jpg/jpeg/png/pdf
        if (!ext.matches("\\.(jpg|jpeg|png|pdf)")) {
            throw new BizException(ResultCode.VALIDATION_FAILED,
                    "仅支持 jpg/jpeg/png/pdf 格式");
        }
        try {
            Path dir = Paths.get(uploadDir, "certificates");
            Files.createDirectories(dir);
            String filename = "cert_" + UUID.randomUUID() + ext;
            Path target = dir.resolve(filename);
            file.transferTo(target.toFile());
            String url = uploadBaseUrl + "/certificates/" + filename;
            return R.ok(java.util.Map.of("url", url, "path", url));
        } catch (IOException e) {
            throw new BizException(ResultCode.FILE_UPLOAD_ERROR, "文件上传失败：" + e.getMessage());
        }
    }

    @Operation(summary = "登出（客户端清除 token 即可，服务端黑名单见 P2）")
    @PostMapping("/logout")
    public R<Void> logout(HttpServletResponse response) {
        clearRefreshCookie(response);
        UserContext.clear();
        return R.ok();
    }

    /** 设置 httpOnly+Secure refresh token cookie（A1 修复：防止 XSS 窃取 refresh token） */
    private void setRefreshCookie(HttpServletResponse response, String refreshToken) {
        ResponseCookie cookie = ResponseCookie.from(REFRESH_COOKIE_NAME, refreshToken)
                .httpOnly(true)
                .secure("prod".equals(activeProfile))
                .sameSite("Strict")
                .path("/api/v1/auth")
                .maxAge(jwtUtils.getRefreshExpireMs() / 1000)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }

    /** 清除 refresh token cookie */
    private void clearRefreshCookie(HttpServletResponse response) {
        ResponseCookie cookie = ResponseCookie.from(REFRESH_COOKIE_NAME, "")
                .httpOnly(true)
                .secure("prod".equals(activeProfile))
                .sameSite("Strict")
                .path("/api/v1/auth")
                .maxAge(0)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }

    /** 从 httpOnly cookie 提取 refresh token */
    private String extractRefreshTokenFromCookie(HttpServletRequest request) {
        Cookie[] cookies = request.getCookies();
        if (cookies == null) return null;
        for (Cookie cookie : cookies) {
            if (REFRESH_COOKIE_NAME.equals(cookie.getName())) {
                return cookie.getValue();
            }
        }
        return null;
    }

    /** 从 HttpServletRequest 解析客户端真实 IP（兼容反向代理） */
    private String clientIp(HttpServletRequest request) {
        if (request == null) return null;
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isBlank() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("X-Real-IP");
        }
        if (ip == null || ip.isBlank() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }
        // 多级代理取第一个
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }
        return ip;
    }
}
