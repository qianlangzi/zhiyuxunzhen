package com.zhiyu.controller;

import com.zhiyu.common.R;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 健康检查（PRD 9.1 前端首页调用，无需鉴权）
 */
@Tag(name = "健康检查")
@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class HealthController {

    private final JdbcTemplate jdbc;

    @Operation(summary = "健康检查（含 DB 探活，无需鉴权）")
    @GetMapping("/health")
    public R<Map<String, Object>> health() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("status", "UP");
        data.put("timestamp", System.currentTimeMillis());
        try {
            jdbc.queryForObject("SELECT 1", Integer.class);
            data.put("db", "UP");
        } catch (Exception e) {
            log.warn("健康检查 DB 探活失败", e);
            data.put("db", "DOWN");
            data.put("status", "DEGRADED");
        }
        return R.ok(data);
    }
}
