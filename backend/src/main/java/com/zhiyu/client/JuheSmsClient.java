package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * 聚合数据（juhe.cn）短信 API 客户端
 *
 * <p>接口文档：https://www.juhe.cn/docs/api/id/54
 *
 * <p>使用方式：
 * <ol>
 *   <li>在聚合数据官网申请短信 API 服务，获取 AppKey</li>
 *   <li>创建短信模板，审核通过后获得模板 ID</li>
 *   <li>设置环境变量 {@code SMS_PROVIDER=juhe}、{@code SMS_JUHE_KEY=xxx}、{@code SMS_JUHE_TPL_ID=xxx}</li>
 * </ol>
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JuheSmsClient {

    /** 聚合数据短信 API 地址 */
    private static final String API_URL = "https://v.juhe.cn/sms/send";

    private final RestTemplate restTemplate;

    @Value("${zhiyu.sms.juhe.key:}")
    private String appKey;

    @Value("${zhiyu.sms.juhe.tpl-id:}")
    private String tplId;

    /**
     * 发送短信验证码
     *
     * @param mobile 接收短信的手机号码
     * @param code   验证码（对应模板中的 #code# 变量）
     * @return 发送结果
     */
    public SendResult send(String mobile, String code) {
        if (appKey == null || appKey.isBlank()) {
            log.error("聚合数据 AppKey 未配置，请设置环境变量 SMS_JUHE_KEY");
            return new SendResult(false, "AppKey 未配置");
        }
        if (tplId == null || tplId.isBlank()) {
            log.error("聚合数据短信模板 ID 未配置，请设置环境变量 SMS_JUHE_TPL_ID");
            return new SendResult(false, "短信模板 ID 未配置");
        }

        try {
            // 模板变量：假设模板中只有一个 #code# 变量
            String vars = URLEncoder.encode(
                    "{\"code\":\"" + code + "\"}",
                    StandardCharsets.UTF_8
            );

            String url = API_URL
                    + "?mobile=" + mobile
                    + "&tpl_id=" + tplId
                    + "&vars=" + vars
                    + "&key=" + appKey;

            log.info("发送短信 phone={} tplId={}", maskPhone(mobile), tplId);

            @SuppressWarnings("unchecked")
            Map<String, Object> resp = restTemplate.postForObject(url, null, Map.class);

            if (resp == null) {
                log.error("短信发送失败：响应为空 phone={}", maskPhone(mobile));
                return new SendResult(false, "短信服务响应为空");
            }

            int errorCode = 0;
            String reason = "";
            if (resp.get("error_code") instanceof Number n) {
                errorCode = n.intValue();
            }
            if (resp.get("reason") instanceof String s) {
                reason = s;
            }

            if (errorCode == 0) {
                log.info("短信发送成功 phone={} sid={}",
                        maskPhone(mobile), resp.get("result"));
                return new SendResult(true, null);
            } else {
                log.error("短信发送失败 error_code={} reason={} phone={}",
                        errorCode, reason, maskPhone(mobile));
                return new SendResult(false, "短信发送失败：" + reason);
            }
        } catch (Exception e) {
            log.error("短信发送异常 phone={}", maskPhone(mobile), e);
            return new SendResult(false, "短信发送异常：" + e.getMessage());
        }
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }

    /** 发送结果 */
    public record SendResult(boolean success, String errorMessage) {}
}