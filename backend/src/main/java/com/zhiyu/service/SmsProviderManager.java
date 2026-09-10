package com.zhiyu.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.client.AliyunSmsAuthClient;
import com.zhiyu.client.JuheSmsClient;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.entity.SysConfig;
import com.zhiyu.mapper.SysConfigMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Locale;

/**
 * 短信服务商运行时管理器（支持管理端热切换）。
 *
 * <p>取值优先级：<b>sys_config 表（管理端可改） &gt; 环境变量 SMS_PROVIDER</b>。
 * 表值带 30 秒进程内缓存，管理端切换后调用 {@link #evict()} 立即生效，
 * 无需重启容器、无需改动服务器 .env。
 *
 * <p>支持的 provider：
 * <ul>
 *   <li>{@code aliyun_auth} —— 阿里云「短信认证」（PNVS/dypnsapi），个人认证可用，推荐</li>
 *   <li>{@code juhe} —— 聚合数据（2025 年实名制新规后可能被运营商拒发）</li>
 *   <li>{@code off} —— 关闭真实发送，仅打日志（演示/联调用）</li>
 * </ul>
 *
 * <p>密钥仍只走环境变量，不落库：切换服务商不需要重新填密钥，只要两边密钥都已注入。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SmsProviderManager {

    public static final String ALIYUN_AUTH = "aliyun_auth";
    public static final String JUHE = "juhe";
    public static final String OFF = "off";
    public static final String CONFIG_KEY = "sms.provider";

    private static final List<String> SUPPORTED = List.of(ALIYUN_AUTH, JUHE, OFF);
    private static final long CACHE_TTL_MS = 30_000L;

    private final SysConfigMapper sysConfigMapper;
    private final AliyunSmsAuthClient aliyunSmsAuthClient;
    private final JuheSmsClient juheSmsClient;

    @Value("${zhiyu.sms.provider:}")
    private String envProvider;

    @Value("${zhiyu.sms.aliyun.access-key-id:}")
    private String aliyunKeyId;

    @Value("${zhiyu.sms.aliyun.access-key-secret:}")
    private String aliyunKeySecret;

    @Value("${zhiyu.sms.aliyun.sign-name:}")
    private String aliyunSignName;

    @Value("${zhiyu.sms.aliyun.template-code:}")
    private String aliyunTemplateCode;

    @Value("${zhiyu.sms.juhe.key:}")
    private String juheKey;

    @Value("${zhiyu.sms.juhe.tpl-id:}")
    private String juheTplId;

    private volatile String cachedProvider;
    private volatile String cachedSource = "NONE";
    private volatile long cachedAt;

    /** 当前生效的 provider（小写）；无任何配置时返回空串 */
    public String current() {
        long now = System.currentTimeMillis();
        if (now - cachedAt < CACHE_TTL_MS) {
            return cachedProvider == null ? "" : cachedProvider;
        }
        String fromDb = readFromDb();
        String value;
        String source;
        if (fromDb != null && !fromDb.isBlank()) {
            value = fromDb;
            source = "DB";
        } else if (envProvider != null && !envProvider.isBlank()) {
            value = envProvider;
            source = "ENV";
        } else {
            value = "";
            source = "NONE";
        }
        cachedProvider = value.trim().toLowerCase(Locale.ROOT);
        cachedSource = source;
        cachedAt = now;
        return cachedProvider;
    }

    /** 当前值来源：DB（管理端配置）/ ENV（环境变量兜底）/ NONE */
    public String currentSource() {
        current();
        return cachedSource;
    }

    /** 使缓存失效，下一次读取立即走 DB */
    public void evict() {
        cachedAt = 0L;
    }

    public List<String> supported() {
        return SUPPORTED;
    }

    /** 环境变量里注入的默认 provider（只读展示用） */
    public String envProvider() {
        return envProvider == null ? "" : envProvider;
    }

    /** 阿里云短信认证密钥/签名/模板是否齐备 */
    public boolean aliyunReady() {
        return !isBlank(aliyunKeyId) && !isBlank(aliyunKeySecret)
                && !isBlank(aliyunSignName) && !isBlank(aliyunTemplateCode);
    }

    /** 聚合数据密钥/模板是否齐备 */
    public boolean juheReady() {
        return !isBlank(juheKey) && !isBlank(juheTplId);
    }

    public String aliyunSignName() {
        return aliyunSignName;
    }

    public String aliyunTemplateCode() {
        return aliyunTemplateCode;
    }

    public String juheTplId() {
        return juheTplId;
    }

    /** 管理端切换服务商：写入 sys_config 并立即生效 */
    public void switchTo(String provider) {
        String target = provider == null ? "" : provider.trim().toLowerCase(Locale.ROOT);
        if (!SUPPORTED.contains(target)) {
            throw new BizException(ResultCode.BAD_REQUEST,
                    "不支持的短信服务商: " + provider + "，可选值: " + String.join("/", SUPPORTED));
        }
        // 防止把可用通道切成"密钥都没配"的通道：宁可切不过去，也不要线上验证码全挂
        if (ALIYUN_AUTH.equals(target) && !aliyunReady()) {
            throw new BizException(ResultCode.SMS_SERVICE_NOT_CONFIGURED,
                    "阿里云短信认证密钥未配置完整（需 ALIYUN_ACCESS_KEY_ID / SECRET / SIGN_NAME / TEMPLATE_CODE），暂不能切换");
        }
        if (JUHE.equals(target) && !juheReady()) {
            throw new BizException(ResultCode.SMS_SERVICE_NOT_CONFIGURED,
                    "聚合数据密钥/模板未配置（需 SMS_JUHE_KEY / SMS_JUHE_TPL_ID），暂不能切换");
        }
        SysConfig existing = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, CONFIG_KEY));
        Long operatorId = UserContext.get() == null ? null : UserContext.get().getUserId();
        if (existing == null) {
            SysConfig config = new SysConfig();
            config.setConfigKey(CONFIG_KEY);
            config.setConfigValue(target);
            config.setConfigType("SMS");
            config.setUpdatedBy(operatorId);
            sysConfigMapper.insert(config);
        } else {
            existing.setConfigValue(target);
            existing.setConfigType("SMS");
            existing.setUpdatedBy(operatorId);
            sysConfigMapper.updateById(existing);
        }
        evict();
        log.info("短信服务商已切换为 {} (by user {})", target, operatorId);
    }

    /**
     * 按当前生效的服务商真实发送验证码（唯一分发点）。
     * 发送链路（{@code RedisSmsCodeService}）与管理端测试接口都走这里，
     * 保证切换后行为一致。
     */
    public SendOutcome send(String phone, String code) {
        String provider = current();
        if (ALIYUN_AUTH.equals(provider)) {
            AliyunSmsAuthClient.SendResult r = aliyunSmsAuthClient.send(phone, code);
            return new SendOutcome(r.success(), provider, r.errorMessage());
        }
        if (JUHE.equals(provider)) {
            JuheSmsClient.SendResult r = juheSmsClient.send(phone, code);
            return new SendOutcome(r.success(), provider, r.errorMessage());
        }
        if (OFF.equals(provider)) {
            log.info("短信服务商为 off（关闭发送），验证码 phone={} code={}", maskPhone(phone), code);
            return new SendOutcome(true, provider, "当前为关闭状态，未真实发送（验证码已写入服务端日志）");
        }
        return new SendOutcome(false, provider, "未配置短信服务商，请在管理端选择或设置 SMS_PROVIDER");
    }

    private String readFromDb() {
        try {
            SysConfig config = sysConfigMapper.selectOne(
                    new LambdaQueryWrapper<SysConfig>().eq(SysConfig::getConfigKey, CONFIG_KEY));
            return config == null ? null : config.getConfigValue();
        } catch (Exception e) {
            // 配置读取失败不能阻断发送链路，降级到环境变量
            log.warn("读取 sys_config[{}] 失败，降级使用环境变量", CONFIG_KEY, e);
            return null;
        }
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }

    /** 发送结果 */
    public record SendOutcome(boolean success, String provider, String message) {}
}
