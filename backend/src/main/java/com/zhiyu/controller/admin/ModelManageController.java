package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.ModelManageService;
import com.zhiyu.service.dto.AiModelDTO;
import com.zhiyu.vo.AiModelVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * AI 模型管理（PRD 4.16 扩展 · 模型管理，约等于 ccswitch 的供应商管理）
 *
 * 仅管理员(role=4)可访问（PermissionInterceptor 默认 /api/v1/admin/** → 4）。
 */
@Tag(name = "管理端-模型管理")
@RestController
@RequestMapping("/api/v1/admin/models")
@RequiredArgsConstructor
public class ModelManageController {

    private final ModelManageService modelManageService;

    @Operation(summary = "模型分页列表（可按能力过滤）")
    @GetMapping
    public R<PageResult<AiModelVO>> page(PageParam param,
                                         @RequestParam(required = false) String capability) {
        return R.ok(modelManageService.page(param, capability));
    }

    @Operation(summary = "新增模型")
    @PostMapping
    public R<AiModelVO> create(@Valid @RequestBody AiModelDTO dto) {
        return R.ok(modelManageService.create(dto));
    }

    @Operation(summary = "更新模型")
    @PutMapping("/{id}")
    public R<AiModelVO> update(@PathVariable Long id, @Valid @RequestBody AiModelDTO dto) {
        return R.ok(modelManageService.update(id, dto));
    }

    @Operation(summary = "删除模型")
    @DeleteMapping("/{id}")
    public R<Void> delete(@PathVariable Long id) {
        modelManageService.delete(id);
        return R.ok();
    }

    @Operation(summary = "切换激活（一键生效，AI 中台热读取）")
    @PostMapping("/{id}/active")
    public R<Void> setActive(@PathVariable Long id) {
        modelManageService.setActive(id);
        return R.ok();
    }

    @Operation(summary = "停用/启用切换")
    @PostMapping("/{id}/toggle")
    public R<Void> toggle(@PathVariable Long id) {
        modelManageService.toggleStatus(id);
        return R.ok();
    }

    @Operation(summary = "连通性测试")
    @PostMapping("/{id}/test")
    public R<Map<String, Object>> test(@PathVariable Long id) {
        return R.ok(modelManageService.testConnect(id));
    }
}