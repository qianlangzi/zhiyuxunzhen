package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.service.TokenUsageService;
import com.zhiyu.service.dto.TokenQuotaDTO;
import com.zhiyu.vo.TokenOverviewVO;
import com.zhiyu.vo.TokenQuotaVO;
import com.zhiyu.vo.TokenRankVO;
import com.zhiyu.vo.TokenTrendPointVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 管理端-Token 管理（V39）
 * 数据来自 AI 中台 llm_client 出口上报，本模块只做查询与配额维护。
 */
@Tag(name = "管理端-Token管理")
@RestController
@RequestMapping("/api/v1/admin/token")
@RequiredArgsConstructor
public class TokenManageController {

    private final TokenUsageService tokenUsageService;

    @Operation(summary = "Token 用量总览（今日/本月/累计 + 配额告警）")
    @GetMapping("/overview")
    public R<TokenOverviewVO> overview() {
        return R.ok(tokenUsageService.overview());
    }

    @Operation(summary = "近 N 天每日用量趋势")
    @GetMapping("/trend")
    public R<List<TokenTrendPointVO>> trend(@RequestParam(defaultValue = "30") int days) {
        return R.ok(tokenUsageService.trend(days));
    }

    @Operation(summary = "用量排行（按模型或场景）")
    @GetMapping("/rank")
    public R<List<TokenRankVO>> rank(@RequestParam(defaultValue = "model") String dimension,
                                     @RequestParam(defaultValue = "30") int days) {
        return R.ok(tokenUsageService.rank(dimension, days));
    }

    @Operation(summary = "配额列表（含本月已用量与告警状态）")
    @GetMapping("/quota")
    public R<List<TokenQuotaVO>> listQuota() {
        return R.ok(tokenUsageService.listQuota());
    }

    @Operation(summary = "新增或更新配额（model 已存在则更新）")
    @PostMapping("/quota")
    public R<Void> saveQuota(@Valid @RequestBody TokenQuotaDTO dto) {
        tokenUsageService.saveQuota(dto);
        return R.ok();
    }

    @Operation(summary = "删除配额")
    @DeleteMapping("/quota/{id}")
    public R<Void> deleteQuota(@PathVariable Long id) {
        tokenUsageService.deleteQuota(id);
        return R.ok();
    }
}
