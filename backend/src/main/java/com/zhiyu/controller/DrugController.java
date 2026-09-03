package com.zhiyu.controller;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.DrugService;
import com.zhiyu.vo.DrugDetailVO;
import com.zhiyu.vo.DrugFilterVO;
import com.zhiyu.vo.DrugListVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 药品库接口（训练中心 · 药房）
 *
 * <p>学生 / 教师通用只读接口：分门别类浏览 + 检索。路径不含角色前缀，
 * 任何已登录用户（学生/教师）均可访问，无需额外授权（与病例广场一致）。
 */
@Tag(name = "药品库")
@RestController
@RequestMapping("/api/v1/drugs")
@RequiredArgsConstructor
public class DrugController {

    private final DrugService drugService;

    @Operation(summary = "药品列表（分页 + 药理分类/科室筛选 + 关键字搜索）")
    @GetMapping("/list")
    public R<PageResult<DrugListVO>> list(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String department,
            @RequestParam(required = false) String keyword) {
        return R.ok(drugService.list(pageNum, pageSize, category, department, keyword));
    }

    @Operation(summary = "筛选维度：药理分类 + 科室（动态去重，供前端筛选项渲染）")
    @GetMapping("/filters")
    public R<DrugFilterVO> filters() {
        return R.ok(drugService.filters());
    }

    @Operation(summary = "药品详情（说明书式教学摘要）")
    @GetMapping("/{id}")
    public R<DrugDetailVO> detail(@PathVariable Long id) {
        return R.ok(drugService.detail(id));
    }
}
