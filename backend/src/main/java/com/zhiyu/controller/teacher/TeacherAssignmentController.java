package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherAssignmentService;
import com.zhiyu.service.dto.AssignmentCreateDTO;
import com.zhiyu.vo.AssignmentProgressVO;
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

/**
 * 教师端-作业管理接口（PRD 4.3 / 9.1）
 */
@Tag(name = "教师-作业管理")
@RestController
@RequestMapping("/api/v1/teacher/assignments")
@RequiredArgsConstructor
public class TeacherAssignmentController {

    private final TeacherAssignmentService teacherAssignmentService;

    @Operation(summary = "创建作业（为班级学生生成实例）")
    @PostMapping
    public R<Long> create(@Valid @RequestBody AssignmentCreateDTO req) {
        return R.ok(teacherAssignmentService.create(req));
    }

    @Operation(summary = "作业进度统计及学生明细")
    @GetMapping("/{id}/progress")
    public R<AssignmentProgressVO> progress(@PathVariable Long id) {
        return R.ok(teacherAssignmentService.progress(id));
    }
}
