package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.service.SmsProviderManager;
import com.zhiyu.service.dto.SmsProviderSwitchRequest;
import com.zhiyu.service.dto.SmsTestSendRequest;
import com.zhiyu.vo.SmsConfigVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;

/**
 * 短信服务商配置（管理端热切换）。
 *
 * <p>背景：2025 年起运营商收紧短信实名制，第三方通道（如聚合数据）随时可能被拒发，
 * 需要在管理端一键切换到备用通道，避免必须改服务器 .env 并重启容器。
 *
 * <p>取值优先级 sys_config(sms.provider) &gt; 环境变量 SMS_PROVIDER，切换即时生效。
 * 密钥仍只存环境变量，切换服务商无需重新填密钥。
 *
 * <p>鉴权：/api/v1/admin/** 由 PermissionInterceptor 限定为管理员（role=4）。
 */
@Slf4j
@Tag(name = "管理端-短信服务商配置")
@RestController
@RequestMapping("/api/v1/admin/sms-config")
@RequiredArgsConstructor
public class SmsConfigController {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final SmsProviderManager smsProviderManager;

    @Operation(summary = "查询短信服务商配置与就绪状态")
    @GetMapping
    public R<SmsConfigVO> get() {
        return R.ok(SmsConfigVO.builder()
                .provider(smsProviderManager.current())
                .source(smsProviderManager.currentSource())
                .envProvider(smsProviderManager.envProvider())
                .supported(smsProviderManager.supported())
                .aliyunReady(smsProviderManager.aliyunReady())
                .juheReady(smsProviderManager.juheReady())
                .aliyunSignName(smsProviderManager.aliyunSignName())
                .aliyunTemplateCode(smsProviderManager.aliyunTemplateCode())
                .juheTplId(smsProviderManager.juheTplId())
                .build());
    }

    @Operation(summary = "切换短信服务商（即时生效）")
    @PutMapping
    public R<Void> switchProvider(@Valid @RequestBody SmsProviderSwitchRequest req) {
        smsProviderManager.switchTo(req.getProvider());
        return R.ok();
    }

    @Operation(summary = "用当前服务商发送一条测试短信")
    @PostMapping("/test")
    public R<Map<String, Object>> testSend(@Valid @RequestBody SmsTestSendRequest req) {
        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        SmsProviderManager.SendOutcome outcome = smsProviderManager.send(req.getPhone(), code);
        Map<String, Object> data = new HashMap<>();
        data.put("success", outcome.success());
        data.put("provider", outcome.provider());
        data.put("message", outcome.message());
        return outcome.success()
                ? R.ok(data)
                : R.fail(com.zhiyu.common.constant.ResultCode.SMS_SERVICE_NOT_CONFIGURED,
                        outcome.message());
    }
}
