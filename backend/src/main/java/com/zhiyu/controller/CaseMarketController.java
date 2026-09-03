package com.zhiyu.controller;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.CaseMarketService;
import com.zhiyu.vo.CaseMarketListVO;
import com.zhiyu.vo.CaseMarketDetailVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 病例广场接口（PRD 4.2 / 9.1）
 */
@Tag(name = "病例广场")
@RestController
@RequestMapping("/api/v1/case-market")
@RequiredArgsConstructor
public class CaseMarketController {

    private final CaseMarketService caseMarketService;

    @Operation(summary = "病例广场列表（公开且审核通过）")
    @GetMapping("/list")
    public R<PageResult<CaseMarketListVO>> list(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String department,
            @RequestParam(required = false) Integer difficulty,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String sortBy,
            @RequestParam(required = false) String order) {
        return R.ok(caseMarketService.list(pageNum, pageSize, department, difficulty, keyword, sortBy, order));
    }

    @Operation(summary = "病例广场在售科室列表（动态去重，供前端筛选项渲染）")
    @GetMapping("/departments")
    public R<List<String>> departments() {
        return R.ok(caseMarketService.departments());
    }

    @Operation(summary = "病例广场公开详情（不含隐藏答案）")
    @GetMapping("/{id}")
    public R<CaseMarketDetailVO> detail(@PathVariable Long id) {
        return R.ok(caseMarketService.detail(id));
    }

    @Operation(summary = "引用病例（复制为独立副本，原病例引用量+1）")
    @PostMapping("/{id}/quote")
    public R<Long> quote(@PathVariable Long id) {
        return R.ok(caseMarketService.quote(id));
    }
}
