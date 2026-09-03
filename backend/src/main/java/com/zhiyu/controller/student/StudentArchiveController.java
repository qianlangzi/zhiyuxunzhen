package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.entity.StudentGoal;
import com.zhiyu.service.StudentGoalService;
import com.zhiyu.service.dto.GoalUpsertRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-学习档案目标管理（P2-1）
 */
@Tag(name = "学生-学习档案")
@RestController
@RequestMapping("/api/v1/student/archive")
@RequiredArgsConstructor
public class StudentArchiveController {

    private final StudentGoalService studentGoalService;

    @Operation(summary = "我的学习目标")
    @GetMapping("/goal")
    public R<StudentGoal> myGoal() {
        return R.ok(studentGoalService.myGoal());
    }

    @Operation(summary = "设定/更新学习目标")
    @PutMapping("/goal")
    public R<Long> upsertGoal(@Valid @RequestBody GoalUpsertRequest req) {
        return R.ok(studentGoalService.upsert(req.getTitle(), req.getTargetMetric(), req.getTargetDate()));
    }
}
