package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.StudentMistakeService;
import com.zhiyu.vo.MistakeVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

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

    @Operation(summary = "单条错题 AI 归因（缓存命中直接返回；未命中调用 AI 并缓存）")
    @PostMapping("/{id}/analyze")
    public R<Map<String, Object>> analyze(@PathVariable Long id) {
        return R.ok(studentMistakeService.analyzeMistake(id));
    }

    @Operation(summary = "练同类题：以错题知识点+归因标签为焦点生成巩固练习")
    @PostMapping("/{id}/drill")
    public R<Map<String, Object>> drill(@PathVariable Long id,
                                        @RequestParam(defaultValue = "5") Integer count) {
        return R.ok(studentMistakeService.generateDrill(id, count == null ? 5 : count));
    }

    @Operation(summary = "回写错题复习状态（0未复习 1已复习 2已掌握）")
    @PostMapping("/{id}/status")
    public R<Void> markResolved(@PathVariable Long id,
                                @RequestParam(required = false) Integer status) {
        studentMistakeService.markResolved(id, status);
        return R.ok();
    }
}
