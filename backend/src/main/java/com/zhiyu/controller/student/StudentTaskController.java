package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherLessonService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 学生端学习任务（智能备课发放闭环）
 * 聚合：备课资料任务（含独立发放的资料）+ 病例作业
 */
@RestController
@RequestMapping("/api/v1/student/tasks")
@RequiredArgsConstructor
public class StudentTaskController {

    private final TeacherLessonService lessonService;

    @GetMapping
    public R<List<Map<String, Object>>> list() {
        return R.ok(lessonService.studentTasks());
    }

    @GetMapping("/{publishId}")
    public R<Map<String, Object>> detail(@PathVariable Long publishId) {
        return R.ok(lessonService.studentTaskDetail(publishId));
    }
}
