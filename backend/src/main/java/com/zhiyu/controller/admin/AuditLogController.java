package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.AdminService;
import com.zhiyu.vo.AuditLogVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

/**
 * 审计日志查询（PRD 4.17）
 */
@Tag(name = "管理端-审计日志")
@RestController
@RequestMapping("/api/v1/admin/audit-logs")
@RequiredArgsConstructor
public class AuditLogController {

    private final AdminService adminService;

    @Operation(summary = "审计日志查询（支持操作人、动作、对象类型、日期范围筛选）")
    @GetMapping
    public R<PageResult<AuditLogVO>> list(PageParam param,
                                          @RequestParam(required = false) Long operatorId,
                                          @RequestParam(required = false) String action,
                                          @RequestParam(required = false) String targetType,
                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return R.ok(adminService.auditLogList(param, operatorId, action, targetType, startDate, endDate));
    }
}
