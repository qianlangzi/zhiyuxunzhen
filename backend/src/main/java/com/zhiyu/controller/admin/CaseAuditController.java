package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.AdminService;
import com.zhiyu.vo.CaseAuditVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 病例审核（PRD 4.15）
 */
@Tag(name = "管理端-病例审核")
@RestController
@RequestMapping("/api/v1/admin/case-audits")
@RequiredArgsConstructor
public class CaseAuditController {

    private final AdminService adminService;

    @Operation(summary = "病例审核列表（待审核）")
    @GetMapping
    public R<PageResult<CaseAuditVO>> list(PageParam param) {
        return R.ok(adminService.caseAuditList(param));
    }

    @Operation(summary = "病例审核通过")
    @PostMapping("/{caseId}/approve")
    public R<Void> approve(@PathVariable Long caseId) {
        adminService.approveCase(caseId);
        return R.ok();
    }

    @Operation(summary = "病例审核驳回")
    @PostMapping("/{caseId}/reject")
    public R<Void> reject(@PathVariable Long caseId) {
        adminService.rejectCase(caseId);
        return R.ok();
    }
}
