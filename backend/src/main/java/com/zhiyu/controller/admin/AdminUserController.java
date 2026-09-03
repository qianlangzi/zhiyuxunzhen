package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.dto.BatchUserIdsDTO;
import com.zhiyu.service.dto.CreateAuditorDTO;
import com.zhiyu.vo.AdminUserStatsVO;
import com.zhiyu.vo.AdminUserVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 管理端-用户管理接口（PRD 4.14 / 4.17）
 * 账号冻结/解冻、修改用户角色，所有操作写审计日志
 */
@Tag(name = "管理端-用户管理")
@RestController
@RequestMapping("/api/v1/admin/users")
@RequiredArgsConstructor
public class AdminUserController {

    private final AdminService adminService;

    @Operation(summary = "冻结账号")
    @PostMapping("/{id}/freeze")
    public R<Void> freeze(@PathVariable Long id) {
        adminService.freezeUser(id);
        return R.ok();
    }

    @Operation(summary = "解冻账号")
    @PostMapping("/{id}/unfreeze")
    public R<Void> unfreeze(@PathVariable Long id) {
        adminService.unfreezeUser(id);
        return R.ok();
    }

    @Operation(summary = "修改用户角色（仅支持 0-3：学生/教师/教学秘书/教研室主任）")
    @PostMapping("/{id}/role")
    public R<Void> changeRole(@PathVariable Long id, @RequestParam Integer role) {
        adminService.changeUserRole(id, role);
        return R.ok();
    }

    @Operation(summary = "开通普通审核员账号（role=6，仅超级管理员可用）")
    @PostMapping("/auditor")
    public R<Void> createAuditor(@Valid @RequestBody CreateAuditorDTO dto) {
        adminService.createAuditor(dto);
        return R.ok();
    }

    @Operation(summary = "用户列表分页查询（人数管理）")
    @GetMapping
    public R<PageResult<AdminUserVO>> list(PageParam param,
                                           @RequestParam(required = false) Integer role,
                                           @RequestParam(required = false) Integer status,
                                           @RequestParam(required = false) String keyword) {
        return R.ok(adminService.listUsers(param, role, status, keyword));
    }

    @Operation(summary = "人数总览：各角色人数 / 冻结数 / 待审教师 / 新增趋势")
    @GetMapping("/stats")
    public R<AdminUserStatsVO> stats() {
        return R.ok(adminService.userStats());
    }

    @Operation(summary = "重置用户密码（返回一次性明文新密码，强制下次登录修改）")
    @PostMapping("/{id}/reset-password")
    public R<Map<String, String>> resetPassword(@PathVariable Long id) {
        String newPassword = adminService.resetPassword(id);
        return R.ok(Map.of("newPassword", newPassword));
    }

    @Operation(summary = "批量冻结账号（跳过管理员/运维及已冻结账号）")
    @PostMapping("/batch-freeze")
    public R<Map<String, Integer>> batchFreeze(@Valid @RequestBody BatchUserIdsDTO dto) {
        return R.ok(Map.of("changed", adminService.batchFreeze(dto.getUserIds(), true)));
    }

    @Operation(summary = "批量解冻账号（跳过仍使用默认弱密码的账号）")
    @PostMapping("/batch-unfreeze")
    public R<Map<String, Integer>> batchUnfreeze(@Valid @RequestBody BatchUserIdsDTO dto) {
        return R.ok(Map.of("changed", adminService.batchFreeze(dto.getUserIds(), false)));
    }
}
