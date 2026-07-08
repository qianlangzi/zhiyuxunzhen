package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.StudentMistakeService;
import com.zhiyu.vo.MistakeVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-错题本接口（PRD 4.11 / 9.1）
 */
@Tag(name = "学生-错题本")
@RestController
@RequestMapping("/api/v1/student/mistakes")
@RequiredArgsConstructor
public class StudentMistakeController {

    private final StudentMistakeService studentMistakeService;

    @Operation(summary = "错题本列表（分页，支持类型筛选）")
    @GetMapping
    public R<PageResult<MistakeVO>> list(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String mistakeType) {
        return R.ok(studentMistakeService.myMistakes(pageNum, pageSize, mistakeType));
    }
}
