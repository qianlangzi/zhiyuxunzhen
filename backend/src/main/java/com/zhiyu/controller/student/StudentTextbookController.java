package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.TextbookService;
import com.zhiyu.vo.TextbookVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-教材中心接口
 */
@Tag(name = "学生-教材中心")
@RestController
@RequestMapping("/api/v1/student/textbooks")
@RequiredArgsConstructor
public class StudentTextbookController {

    private final TextbookService textbookService;

    @Operation(summary = "教材分页列表（支持科室筛选 + 关键词搜索）")
    @GetMapping
    public R<PageResult<TextbookVO>> page(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String department,
            @RequestParam(required = false) String keyword) {
        return R.ok(textbookService.page(pageNum, pageSize, department, keyword));
    }

    @Operation(summary = "教材详情")
    @GetMapping("/{id}")
    public R<TextbookVO> detail(@PathVariable Long id) {
        return R.ok(textbookService.detail(id));
    }
}