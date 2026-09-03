package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentReportService;
import com.zhiyu.vo.StudentLearningOverviewVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-成长概览接口（原复盘报告 export 已于 2026-09-02 下线）
 */
@Tag(name = "学生-成长概览")
@RestController
@RequestMapping("/api/v1/student/review-report")
@RequiredArgsConstructor
public class StudentReportController {

    private final StudentReportService studentReportService;

    @Operation(summary = "学生能力与近 90 天训练活动概览")
    @GetMapping("/overview")
    public R<StudentLearningOverviewVO> overview() {
        return R.ok(studentReportService.overview());
    }
}
