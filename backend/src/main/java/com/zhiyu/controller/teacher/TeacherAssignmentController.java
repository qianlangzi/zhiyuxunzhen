package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherAssignmentService;
import com.zhiyu.service.dto.AssignmentCreateDTO;
import com.zhiyu.service.dto.AssignmentSettingsDTO;
import com.zhiyu.vo.AssignmentProgressVO;
import com.zhiyu.vo.TeacherAssignmentListVO;
import com.zhiyu.vo.TeachingClassVO;
import java.util.List;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
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

    @Operation(summary = "我的作业列表")
    @GetMapping
    public R<List<TeacherAssignmentListVO>> list() {
        return R.ok(teacherAssignmentService.list());
    }

    @Operation(summary = "当前教师已获授权的班级")
    @GetMapping("/classes")
    public R<List<TeachingClassVO>> classes() {
        return R.ok(teacherAssignmentService.classes());
    }

    @Operation(summary = "创建作业（为班级学生生成实例）")
    @PostMapping
    public R<Long> create(@Valid @RequestBody AssignmentCreateDTO req) {
        return R.ok(teacherAssignmentService.create(req));
    }

    @Operation(summary = "修改作业设置（延期 / 补交窗口 / 公布策略等，null 字段表示不修改）")
    @PutMapping("/{id}/settings")
    public R<Void> updateSettings(@PathVariable Long id,
                                  @RequestBody AssignmentSettingsDTO req) {
        teacherAssignmentService.updateSettings(id, req);
        return R.ok();
    }

    @Operation(summary = "作业进度统计及学生明细")
    @GetMapping("/{id}/progress")
    public R<AssignmentProgressVO> progress(@PathVariable Long id) {
        return R.ok(teacherAssignmentService.progress(id));
    }
}
