package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.DailyCaseService;
import com.zhiyu.service.dto.DailyCaseScheduleDTO;
import com.zhiyu.vo.DailyCaseVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端-每日一例排期接口（PRD 4.16 / 8.10）
 * 管理员为"每日一例"功能排期病例，发布后学生在学生端可见
 */
@Tag(name = "管理端-每日一例排期")
@RestController
@RequestMapping("/api/v1/admin/daily-cases")
@RequiredArgsConstructor
public class AdminDailyCaseController {

    private final DailyCaseService dailyCaseService;

    @Operation(summary = "排期每日一例（指定日期 + 病例，立即发布）")
    @PostMapping
    public R<Long> schedule(@Valid @RequestBody DailyCaseScheduleDTO dto) {
        return R.ok(dailyCaseService.schedule(dto));
    }

    @Operation(summary = "排期列表（分页，按发布日期倒序）")
    @GetMapping
    public R<PageResult<DailyCaseVO>> list(PageParam param) {
        return R.ok(dailyCaseService.scheduleList(param.getPageNum(), param.getPageSize()));
    }
}
