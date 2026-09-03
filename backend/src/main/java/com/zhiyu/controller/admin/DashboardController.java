package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.DashboardStatsService;
import com.zhiyu.vo.DashboardVO;
import com.zhiyu.vo.TrendPointVO;
import com.zhiyu.vo.UserOverviewVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

/**
 * 全局驾驶舱（PRD 4.13）+ 用户数据看板（在线/注册/活跃趋势）
 */
@Tag(name = "管理端-驾驶舱")
@RestController
@RequestMapping("/api/v1/admin/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final AdminService adminService;
    private final DashboardStatsService dashboardStatsService;

    @Operation(summary = "全局驾驶舱聚合指标")
    @GetMapping
    public R<DashboardVO> dashboard() {
        return R.ok(adminService.dashboard());
    }

    @Operation(summary = "用户数据看板总览：注册/活跃/在线")
    @GetMapping("/user-overview")
    public R<UserOverviewVO> userOverview() {
        return R.ok(dashboardStatsService.userOverview());
    }

    @Operation(summary = "某日在线人数走势（5分钟采样折线）")
    @GetMapping("/online-trend")
    public R<List<TrendPointVO>> onlineTrend(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return R.ok(dashboardStatsService.onlineTrend(date != null ? date : LocalDate.now()));
    }

    @Operation(summary = "近 N 天每日新增注册趋势")
    @GetMapping("/register-trend")
    public R<List<TrendPointVO>> registerTrend(@RequestParam(defaultValue = "30") int days) {
        return R.ok(dashboardStatsService.registerTrend(days));
    }

    @Operation(summary = "近 N 天每日活跃(DAU)与峰值在线趋势")
    @GetMapping("/active-trend")
    public R<List<TrendPointVO>> activeTrend(@RequestParam(defaultValue = "30") int days) {
        return R.ok(dashboardStatsService.activeTrend(days));
    }
}
