package com.zhiyu.config;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 演示数据初始化（PRD 演示账号 teacher01 / student01 / admin01，密码 123456）
 * 仅在对应账号不存在时插入，不覆盖已有数据
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    private final SysUserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        String hash = passwordEncoder.encode("123456");
        List<DemoUser> demos = List.of(
                new DemoUser("teacher01", "张老师", 1, 2, "18500000001"),
                new DemoUser("student01", "李同学", 0, 0, "18500000002"),
                new DemoUser("admin01", "系统管理员", 4, 2, "18500000003")
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
    }

    private record DemoUser(String username, String realName, Integer role, Integer auditStatus, String phone) {}
}
