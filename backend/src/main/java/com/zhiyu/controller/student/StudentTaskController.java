package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherLessonService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 学生端学习任务（智能备课发放闭环）
 * 聚合：备课资料任务（含独立发放的资料）+ 病例作业
 */
@Tag(name = "学生-学习任务")
@RestController
@RequestMapping("/api/v1/student/tasks")
@RequiredArgsConstructor
public class StudentTaskController {

    private final TeacherLessonService lessonService;

    @Operation(summary = "学习任务聚合列表（资料任务 + 作业任务）")
    @GetMapping
    public R<List<Map<String, Object>>> list() {
        return R.ok(lessonService.studentTasks());
    }

    @Operation(summary = "单个学习任务详情")
    @GetMapping("/{publishId}")
    public R<Map<String, Object>> detail(@PathVariable Long publishId) {
        return R.ok(lessonService.studentTaskDetail(publishId));
    }

    @Operation(summary = "标记资料任务完成（幂等；完成后从待办与课程角标清除）")
    @PostMapping("/lesson-tasks/{publishId}/complete")
    public R<Void> completeLessonTask(@PathVariable Long publishId) {
        lessonService.completeLessonTask(publishId);
        return R.ok();
    }
}
