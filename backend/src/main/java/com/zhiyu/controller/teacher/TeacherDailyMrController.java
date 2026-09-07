package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.DailyMrService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 教师端-每日病历闭环：批阅台（AI 初筛）+ 复核 + 班级缺陷热力图
 */
@Tag(name = "教师-每日病历")
@RestController
@RequestMapping("/api/v1/teacher/daily-cases/mr")
@RequiredArgsConstructor
public class TeacherDailyMrController {

    private final DailyMrService dailyMrService;

    @Operation(summary = "最近期次列表（批阅台选期用）")
    @GetMapping("/schedules")
    public R<List<Map<String, Object>>> schedules(
            @RequestParam(defaultValue = "30") int limit) {
        return R.ok(dailyMrService.schedules(limit));
    }

    @Operation(summary = "批阅台：某期学生病历列表（AI 置信度透出，needReview=true 优先复核）")
    @GetMapping("/records")
    public R<PageResult<Map<String, Object>>> records(
            @RequestParam Long scheduleId,
            @RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "20") int pageSize) {
        return R.ok(dailyMrService.teacherRecords(scheduleId, pageNum, pageSize));
    }

    @Operation(summary = "复核改分：教师最终分覆盖 AI 分（score 0-100 可空）")
    @PatchMapping("/records/{recordId}/review")
    public R<Map<String, Object>> review(
            @PathVariable Long recordId,
            @RequestParam(required = false) Double score,
            @RequestParam(required = false) String comment) {
        return R.ok(dailyMrService.teacherReview(recordId, score, comment));
    }

    @Operation(summary = "班级缺陷统计（热力图数据源；scheduleId 可空=全部期次）")
    @GetMapping("/defect-stats")
    public R<List<Map<String, Object>>> defectStats(
            @RequestParam(required = false) Long scheduleId) {
        return R.ok(dailyMrService.defectStats(scheduleId));
    }
}
