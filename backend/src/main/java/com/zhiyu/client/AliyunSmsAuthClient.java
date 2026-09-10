package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;

/**
 * 阿里云「号码认证服务（PNVS）→ 短信认证」客户端。
 *
 * <p>为什么用它：2025 年起工信部/运营商收紧短信实名制，普通短信服务（dysmsapi）的签名
 * 必须完成运营商实名报备，而<b>个人认证资质无法报备</b>，导致个人开发者无法使用普通短信服务。
 * 短信认证（dypnsapi）是阿里云为个人开发者提供的合规通道：免资质、免签名申请，
 * 使用平台赠送的签名与模板。
 *
 * <p>接口：Action=SendSmsVerifyCode，Version=2017-05-25，接入点 dypnsapi.aliyuncs.com。
 *
 * <p>设计要点：TemplateParam 中的 code 直接传<b>本系统自己生成的验证码明文</b>
 * （而非 "##code##" 占位符），因此验证码的生成/存储/校验仍由后端 Redis 流程掌控
 * （{@code RedisSmsCodeService}），阿里云只负责投递，链路改动最小。
 * 注意：此种传法阿里云侧无法校验，校验必须由本系统完成。
 *
 * <p>鉴权使用阿里云 RPC 签名 V1.0（HMAC-SHA1），手工实现以避免引入新的 SDK 依赖，
 * 降低线上镜像构建（离线 Maven）失败风险。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AliyunSmsAuthClient {

    private static final String ENDPOINT = "https://dypnsapi.aliyuncs.com/";
    private static final String API_VERSION = "2017-05-25";
    private static final String ACTION = "SendSmsVerifyCode";
    private static final DateTimeFormatter TIMESTAMP_FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss'Z'").withZone(ZoneOffset.UTC);

    private final RestTemplate restTemplate;

    @Value("${zhiyu.sms.aliyun.access-key-id:}")
    private String accessKeyId;

    @Value("${zhiyu.sms.aliyun.access-key-secret:}")
    private String accessKeySecret;

    /** 平台赠送签名，如「恒创联众」（短信认证控制台 → 赠送签名配置） */
    @Value("${zhiyu.sms.aliyun.sign-name:}")
    private String signName;

    /** 平台赠送模板 CODE，如 100001（短信认证控制台 → 赠送模板配置） */
    @Value("${zhiyu.sms.aliyun.template-code:}")
    private String templateCode;

    /** 验证码有效期（秒），需与 Redis CODE_TTL 保持一致，默认 300 */
    @Value("${zhiyu.sms.aliyun.valid-seconds:300}")
    private int validSeconds;

    /** 方案名称，留空使用「默认方案」 */
    @Value("${zhiyu.sms.aliyun.scheme-name:}")
    private String schemeName;

    /**
     * 发送短信验证码。
     *
     * @param phone 手机号（11 位，国内）
     * @param code  本系统生成的验证码明文（6 位数字）
     * @return 发送结果
     */
    public SendResult send(String phone, String code) {
        if (isBlank(accessKeyId) || isBlank(accessKeySecret)) {
            log.error("阿里云短信认证 AccessKey 未配置，请设置 ALIYUN_ACCESS_KEY_ID / ALIYUN_ACCESS_KEY_SECRET");
            return new SendResult(false, "阿里云 AccessKey 未配置");
        }
        if (isBlank(signName)) {
            log.error("阿里云短信认证签名未配置，请设置 ALIYUN_SMS_SIGN_NAME");
            return new SendResult(false, "阿里云短信认证签名未配置");
        }
        if (isBlank(templateCode)) {
            log.error("阿里云短信认证模板 CODE 未配置，请设置 ALIYUN_SMS_TEMPLATE_CODE");
            return new SendResult(false, "阿里云短信认证模板 CODE 未配置");
        }

        try {
            // 模板变量：赠送模板形如「您的验证码为${code}，……${min}分钟内有效……」
            String templateParam = String.format("{\"code\":\"%s\",\"min\":\"%d\"}",
                    code, Math.max(1, validSeconds / 60));

            Map<String, String> params = new TreeMap<>();
            params.put("AccessKeyId", accessKeyId);
            params.put("Action", ACTION);
            params.put("AutoRetry", "1");
            params.put("CodeLength", "6");
            params.put("DuplicatePolicy", "1");
            params.put("Format", "JSON");
            params.put("PhoneNumber", phone);
            params.put("SignatureMethod", "HMAC-SHA1");
            params.put("SignatureNonce", UUID.randomUUID().toString());
            params.put("SignatureVersion", "1.0");
            params.put("SignName", signName);
            params.put("TemplateCode", templateCode);
            params.put("TemplateParam", templateParam);
            params.put("Timestamp", TIMESTAMP_FMT.format(Instant.now()));
            params.put("ValidTime", String.valueOf(validSeconds));
            params.put("Version", API_VERSION);
            if (!isBlank(schemeName)) {
                params.put("SchemeName", schemeName);
            }
            params.put("Signature", sign(params));

            log.info("阿里云短信认证发送 phone={} sign={} tpl={}", maskPhone(phone), signName, templateCode);

            MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
            params.forEach(form::add);
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
            HttpEntity<MultiValueMap<String, String>> entity = new HttpEntity<>(form, headers);

            @SuppressWarnings("unchecked")
            Map<String, Object> resp = restTemplate
                    .exchange(ENDPOINT, HttpMethod.POST, entity, Map.class).getBody();

            if (resp == null) {
                log.error("阿里云短信认证响应为空 phone={}", maskPhone(phone));
                return new SendResult(false, "短信服务响应为空");
            }

            Object codeObj = resp.get("Code");
            String bizCode = codeObj == null ? "" : codeObj.toString();
            boolean success = Boolean.TRUE.equals(resp.get("Success")) || "OK".equalsIgnoreCase(bizCode);
            if (success) {
                log.info("阿里云短信认证发送成功 phone={}", maskPhone(phone));
                return new SendResult(true, null);
            }

            String message = resp.get("Message") == null ? "未知错误" : resp.get("Message").toString();
            log.error("阿里云短信认证发送失败 Code={} Message={} phone={}", bizCode, message, maskPhone(phone));
            return new SendResult(false, "短信发送失败：" + message);
        } catch (Exception e) {
            log.error("阿里云短信认证发送异常 phone={}", maskPhone(phone), e);
            return new SendResult(false, "短信发送异常：" + e.getMessage());
        }
    }

    /** 阿里云 RPC 签名 V1.0：HMAC-SHA1(accessKeySecret + "&", StringToSign) */
    private String sign(Map<String, String> params) throws Exception {
        StringBuilder canonical = new StringBuilder();
        for (Map.Entry<String, String> e : params.entrySet()) {
            if (canonical.length() > 0) {
                canonical.append('&');
            }
            canonical.append(percentEncode(e.getKey())).append('=').append(percentEncode(e.getValue()));
        }
        String stringToSign = "POST&" + percentEncode("/") + "&" + percentEncode(canonical.toString());

        Mac mac = Mac.getInstance("HmacSHA1");
        mac.init(new SecretKeySpec((accessKeySecret + "&").getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
        return Base64.getEncoder().encodeToString(mac.doFinal(stringToSign.getBytes(StandardCharsets.UTF_8)));
    }

    /** 阿里云要求的百分号编码：与 URLEncoder 的差异在 +、*、~ 三个字符 */
    private static String percentEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8)
                .replace("+", "%20")
                .replace("*", "%2A")
                .replace("%7E", "~");
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }

    /** 发送结果 */
    public record SendResult(boolean success, String errorMessage) {}
}
