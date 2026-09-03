package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.dto.SysConfigUpdateDTO;
import com.zhiyu.vo.SysConfigVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 系统配置管理（PRD 4.16）
 */
@Tag(name = "管理端-系统配置")
@RestController
@RequestMapping("/api/v1/admin/sys-config")
@RequiredArgsConstructor
public class SysConfigController {

    private final AdminService adminService;

    @Operation(summary = "查询全部系统配置")
    @GetMapping
    public R<List<SysConfigVO>> list() {
        return R.ok(adminService.listSysConfig());
    }

    @Operation(summary = "更新系统配置（upsert）")
    @PutMapping
    public R<Void> update(@Valid @RequestBody SysConfigUpdateDTO dto) {
        adminService.updateSysConfig(dto);
        return R.ok();
    }
}
