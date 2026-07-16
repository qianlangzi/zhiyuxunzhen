package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.DailyCaseService;
import com.zhiyu.service.dto.DailyCaseAnswerDTO;
import com.zhiyu.vo.DailyCaseVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-每日一例接口（PRD 4.10.2）
 * 学生获取今日病例并提交答案，由 AI 中台即时评估
 */
@Tag(name = "学生-每日一例")
@RestController
@RequestMapping("/api/v1/student/daily-cases")
@RequiredArgsConstructor
public class StudentDailyCaseController {

    private final DailyCaseService dailyCaseService;

    @Operation(summary = "获取今日每日一例（无排期返回 data=null）")
    @GetMapping("/today")
    public R<DailyCaseVO> today() {
        return R.ok(dailyCaseService.today());
    }

    @Operation(summary = "提交每日一例答案（同步调用 AI 评估，返回评估结果 JSON）")
    @PostMapping("/submit")
    public R<String> submit(@Valid @RequestBody DailyCaseAnswerDTO dto) {
        return R.ok(dailyCaseService.submitAnswer(dto));
    }
}
