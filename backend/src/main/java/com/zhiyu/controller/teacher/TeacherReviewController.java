package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherReviewService;
import com.zhiyu.service.dto.ReviewOverrideDTO;
import com.zhiyu.vo.TeacherReviewVO;
import com.zhiyu.vo.TeacherReviewQueueVO;
import java.util.List;
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
 * 教师端-批阅复核接口（PRD 4.4.4 / 5.3 第 7 步）
 * 教师查看 AI 批阅结果并人工覆盖，最终成绩以教师复核为准
 */
@Tag(name = "教师-批阅复核")
@RestController
@RequestMapping("/api/v1/teacher/reviews")
@RequiredArgsConstructor
public class TeacherReviewController {

    private final TeacherReviewService teacherReviewService;

    @Operation(summary = "我的批阅队列")
    @GetMapping
    public R<List<TeacherReviewQueueVO>> list() {
        return R.ok(teacherReviewService.list());
    }

    @Operation(summary = "查询作业实例的最新批阅记录（教师覆盖优先，否则 AI 批阅）")
    @GetMapping("/{instanceId}")
    public R<TeacherReviewVO> getReview(@PathVariable Long instanceId) {
        return R.ok(teacherReviewService.getReview(instanceId));
    }

    @Operation(summary = "教师人工覆盖 AI 批阅结果")
    @PostMapping("/{instanceId}/override")
    public R<Long> override(@PathVariable Long instanceId, @Valid @RequestBody ReviewOverrideDTO dto) {
        return R.ok(teacherReviewService.overrideReview(instanceId, dto));
    }
}
