package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentReportService;
import com.zhiyu.service.dto.ExportReportDTO;
import com.zhiyu.vo.ReviewReportVO;
import com.zhiyu.vo.StudentLearningOverviewVO;
import org.springframework.web.bind.annotation.GetMapping;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-复盘报告接口（PRD 4.11 / 9.1）
 */
@Tag(name = "学生-复盘报告")
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

    @Operation(summary = "导出复盘报告")
    @PostMapping("/export")
    public R<ReviewReportVO> export(@Valid @RequestBody ExportReportDTO req) {
        return R.ok(studentReportService.export(req));
    }
}
