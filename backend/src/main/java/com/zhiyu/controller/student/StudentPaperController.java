package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentPaperService;
import com.zhiyu.service.dto.PaperGenerateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 学生端 AI 组卷接口（P2-4 学生自测卷）
 * 基于薄弱知识点 + 难度偏好一键生成个性化自测卷；AI 不可用时规则组卷兜底。
 * 组卷已异步化：POST /tasks 提交任务 → 轮询 GET /tasks/{taskId}。
 */
@Tag(name = "学生-AI组卷")
@RestController
@RequestMapping("/api/v1/student/paper")
@RequiredArgsConstructor
public class StudentPaperController {

    private final StudentPaperService studentPaperService;

    @Operation(summary = "生成个性化自测卷（AI 选题组卷，薄弱点优先）")
    @PostMapping("/generate")
    public R<Map<String, Object>> generate(@Valid @RequestBody PaperGenerateRequest req) {
        return R.ok(studentPaperService.generate(req));
    }

    @Operation(summary = "提交异步组卷任务，返回 taskId（客户端轮询任务结果）")
    @PostMapping("/tasks")
    public R<Map<String, Object>> submitTask(@Valid @RequestBody PaperGenerateRequest req) {
        return R.ok(studentPaperService.submitTask(req));
    }

    @Operation(summary = "查询组卷任务结果（status + paper）")
    @GetMapping("/tasks/{taskId}")
    public R<Map<String, Object>> getTask(@PathVariable String taskId) {
        return R.ok(studentPaperService.getTask(taskId));
    }
}
