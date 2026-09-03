package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.service.TeacherDashboardService;
import com.zhiyu.vo.TeacherDashboardVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 教师学情看板接口
 */
@Tag(name = "教师学情看板")
@RestController
@RequestMapping("/api/v1/teacher/dashboard")
@RequiredArgsConstructor
public class TeacherDashboardController {

    private final TeacherDashboardService teacherDashboardService;

    @Operation(summary = "获取教师学情概览（可按班级维度筛选）")
    @GetMapping("/overview")
    public R<TeacherDashboardVO> overview(@RequestParam(required = false) Long classId) {
        Long teacherId = UserContext.requireUserId();
        return R.ok(teacherDashboardService.getOverview(teacherId, classId));
    }
}