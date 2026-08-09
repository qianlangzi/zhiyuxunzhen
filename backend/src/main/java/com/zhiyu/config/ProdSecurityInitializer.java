package com.zhiyu.config;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 生产环境安全初始化（仅 prod profile 激活）
 *
 * 作用：如果数据库中仍存在使用演示密码 123456 的演示账号（admin01/teacher01/student01），
 * 自动将其冻结（status=1），防止弱密码账号在生产环境被利用。
 *
 * 场景：开发环境曾连接过生产数据库并创建了演示账号，切换到生产部署后残留。
 * DataInitializer 在 prod 已通过 demo-data=false 禁止新增，本类处理存量数据。
 */
@Slf4j
@Component
@Profile("prod")
@RequiredArgsConstructor
public class ProdSecurityInitializer implements CommandLineRunner {

    /** 演示账号用户名列表 */
    private static final List<String> DEMO_USERNAMES = List.of("admin01", "teacher01", "student01");

    /** 演示账号明文密码，用于匹配判断 */
    private static final String DEMO_PASSWORD = "123456";

    private final SysUserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        int disabled = 0;
        for (String username : DEMO_USERNAMES) {
            SysUser user = userMapper.selectOne(
                    new LambdaQueryWrapper<SysUser>().eq(SysUser::getUsername, username));
            if (user == null) {
                continue;
            }
            // 仅冻结密码仍为演示密码 123456 的账号，避免误冻结已改密的真实账号
            if (!passwordEncoder.matches(DEMO_PASSWORD, user.getPasswordHash())) {
                log.warn("演示账号 {} 已修改密码，跳过冻结", username);
                continue;
            }
            if (user.getStatus() != null && user.getStatus() == 1) {
                log.info("演示账号 {} 已处于冻结状态，无需重复操作", username);
                continue;
            }
            userMapper.update(null,
                    new LambdaUpdateWrapper<SysUser>()
                            .eq(SysUser::getId, user.getId())
                            .set(SysUser::getStatus, 1));
            log.warn("安全告警：已冻结演示账号 {}（密码仍为默认 123456），请立即删除或重置密码", username);
            disabled++;
        }
        if (disabled > 0) {
            log.error("生产环境检测到 {} 个弱密码演示账号并已冻结，请尽快清理", disabled);
        }
    }
}
