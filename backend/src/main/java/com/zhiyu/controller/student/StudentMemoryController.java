package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.CompanionMemory;
import com.zhiyu.service.CompanionMemoryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生-AI 学伴记忆管理（查看 / 单条删除 / 清空）
 */
@Tag(name = "学生-AI学伴记忆管理")
@RestController
@RequestMapping("/api/v1/student/memories")
@RequiredArgsConstructor
public class StudentMemoryController {

    private final CompanionMemoryService memoryService;

    @Operation(summary = "AI 学伴记忆列表（分页，按时间倒序）")
    @GetMapping
    public R<PageResult<CompanionMemory>> list(
            @RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "50") int pageSize) {
        return R.ok(memoryService.page(pageNum, pageSize));
    }

    @Operation(summary = "删除一条 AI 学伴记忆")
    @DeleteMapping("/{id}")
    public R<Void> delete(@PathVariable Long id) {
        memoryService.deleteOwned(id);
        return R.ok();
    }

    @Operation(summary = "清空全部 AI 学伴记忆")
    @DeleteMapping("/clear")
    public R<Void> clear() {
        memoryService.clearAll();
        return R.ok();
    }
}
