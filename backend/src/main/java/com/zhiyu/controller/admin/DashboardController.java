package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.service.AdminService;
import com.zhiyu.vo.DashboardVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 全局驾驶舱（PRD 4.13）
 */
@Tag(name = "管理端-驾驶舱")
@RestController
@RequestMapping("/api/v1/admin/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final AdminService adminService;

    @Operation(summary = "全局驾驶舱聚合指标")
    @GetMapping
    public R<DashboardVO> dashboard() {
        return R.ok(adminService.dashboard());
    }
}
