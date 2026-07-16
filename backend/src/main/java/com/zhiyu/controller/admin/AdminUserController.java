package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.service.AdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

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
}
