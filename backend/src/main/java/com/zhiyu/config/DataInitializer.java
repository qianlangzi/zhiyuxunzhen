package com.zhiyu.config;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.entity.AiModel;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.AiModelMapper;
import com.zhiyu.mapper.SysUserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;

/**
 * 演示数据初始化（PRD 演示账号 teacher01 / student01 / admin01，密码 123456）
 * 仅在对应账号不存在时插入，不覆盖已有数据
 *
 * 双重隔离：
 *   1. @Profile({"dev","test"}) — 仅 dev/test profile 注册此 Bean
 *   2. @Value("${zhiyu.init.demo-data:false}") — 属性开关，默认 false
 * prod profile 下此 Bean 不存在，即使属性被误设为 true 也不会执行
 */
@Slf4j
@Component
@Profile({"dev", "test"})
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final SysUserMapper userMapper;
    private final AiModelMapper aiModelMapper;
    private final PasswordEncoder passwordEncoder;

    /**
     * 演示数据开关（zhiyu.init.demo-data）：
     * - dev/test profile 默认 true，自动创建演示账号
     * - prod profile 默认 false（application-prod.yml 不配置该项，主配置无默认值时回退 false）
     * - 生产环境严禁开启，避免创建 admin01/123456 弱密码账号
     */
    @Value("${zhiyu.init.demo-data:false}")
    private boolean demoDataEnabled;

    @Override
    public void run(String... args) {
        if (!demoDataEnabled) {
            log.info("演示数据初始化已禁用 (zhiyu.init.demo-data=false)，跳过");
            return;
        }
        String hash = passwordEncoder.encode("123456");
        List<DemoUser> demos = List.of(
                new DemoUser("teacher01", "张老师", 1, 2, "18500000001"),
                new DemoUser("student01", "李同学", 0, 0, "18500000002"),
                new DemoUser("admin01", "系统管理员", 4, 2, "18500000003"),
                new DemoUser("auditor01", "内容审核员", 6, 2, "18500000004")
        );
        for (DemoUser d : demos) {
            Long exists = userMapper.selectCount(
                    new LambdaQueryWrapper<SysUser>().eq(SysUser::getUsername, d.username));
            if (exists != null && exists > 0) {
                continue;
            }
            SysUser u = new SysUser();
            u.setUsername(d.username);
            u.setPasswordHash(hash);
            u.setRealName(d.realName);
            u.setRole(d.role);
            u.setAuditStatus(d.auditStatus);
            u.setPhone(d.phone);
            u.setStatus(0);
            userMapper.insert(u);
            log.info("演示账号已初始化: {} ({})", d.username, d.realName);
        }
        seedAiModels();
    }

    /**
     * 预置当前项目实际在用的 4 个能力模型（LLM/VISION/EMBEDDING/EMBEDDING_MULTI）。
     * 模型密钥与地址一律从环境变量读取（DEEPSEEK_API_KEY / DASHSCOPE_HOST /
     * DASHSCOPE_API_KEY / SILICONFLOW_API_KEY），写入 ai_model 表；在部署环境配置好
     * 对应变量后管理端「模型管理」开箱即用。仅在该能力未配置任何模型时插入，不覆盖已有配置。
     */
    private static String env(String key) {
        String v = System.getenv(key);
        return v != null ? v : "";
    }

    private void seedAiModels() {
        List<ModelSeed> seeds = List.of(
                new ModelSeed("DeepSeek V4 Flash", "DeepSeek", "LLM",
                        "https://api.deepseek.com/v1",
                        env("DEEPSEEK_API_KEY"),
                        "deepseek-chat", null, 2048, new BigDecimal("0.7")),
                new ModelSeed("qwen3-omni-flash 视觉", "阿里云 MaaS", "VISION",
                        env("DASHSCOPE_HOST") + "/compatible-mode/v1",
                        env("DASHSCOPE_API_KEY"),
                        "qwen3-omni-flash", null, 2048, new BigDecimal("0.7")),
                new ModelSeed("bge-m3 文本向量", "SiliconFlow", "EMBEDDING",
                        "https://api.siliconflow.cn/v1",
                        env("SILICONFLOW_API_KEY"),
                        "BAAI/bge-m3", 1024, null, null),
                new ModelSeed("qwen3-vl-embedding 多模态", "阿里云 MaaS", "EMBEDDING_MULTI",
                        env("DASHSCOPE_HOST") + "/api/v1",
                        env("DASHSCOPE_API_KEY"),
                        "qwen3-vl-embedding", 1024, null, null)
        );
        for (ModelSeed s : seeds) {
            Long exists = aiModelMapper.selectCount(
                    new LambdaQueryWrapper<AiModel>().eq(AiModel::getCapability, s.capability()));
            if (exists != null && exists > 0) {
                continue; // 该能力已配置过模型，跳过预置，尊重已有管理配置
            }
            AiModel m = new AiModel();
            m.setName(s.name());
            m.setProvider(s.provider());
            m.setCapability(s.capability());
            m.setBaseUrl(s.baseUrl());
            m.setApiKey(s.apiKey());
            m.setModel(s.model());
            m.setDimension(s.dimension());
            m.setTimeoutSeconds(30);
            m.setMaxTokens(s.maxTokens());
            m.setTemperature(s.temperature());
            m.setIsActive(true);   // 当前项目默认启用并激活这套能力
            m.setStatus(1);
            m.setDescription("演示环境预置，与 .env 保持一致，可在管理端调整或切换激活");
            aiModelMapper.insert(m);
            log.info("预置模型已初始化: {} ({})", s.name(), s.capability());
        }
    }

    private record ModelSeed(String name, String provider, String capability,
                             String baseUrl, String apiKey, String model,
                             Integer dimension, Integer maxTokens, BigDecimal temperature) {}

    private record DemoUser(String username, String realName, Integer role, Integer auditStatus, String phone) {}
}
