package com.zhiyu;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 智愈寻真 - 业务中台启动入口
 * 负责系统鉴权、高频 CRUD、文件网关(见 PRD 3.2)
 */
@SpringBootApplication
@MapperScan("com.zhiyu.mapper")
public class ZhiyuApplication {
    public static void main(String[] args) {
        SpringApplication.run(ZhiyuApplication.class, args);
    }
}
