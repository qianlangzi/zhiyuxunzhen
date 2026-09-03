package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.ReviewAppealService;
import com.zhiyu.service.dto.ReviewAppealCreateDTO;
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

import java.util.List;
import java.util.Map;

/**
 * 学生端-批阅申诉（PRD 4.4.5）
 * 学生对已出批阅结果的大病历/主观题发起申诉，并查看处理状态。
 */
@Tag(name = "学生-批阅申诉")
@RestController
@RequestMapping("/api/v1/student/appeals")
@RequiredArgsConstructor
public class StudentAppealController {

    private final ReviewAppealService reviewAppealService;

    @Operation(summary = "对指定作业实例发起批阅申诉")
    @PostMapping("/{instanceId}")
    public R<Long> create(@PathVariable Long instanceId,
                          @Valid @RequestBody ReviewAppealCreateDTO dto) {
        return R.ok(reviewAppealService.create(instanceId, dto.getReason()));
    }

    @Operation(summary = "我的申诉列表")
    @GetMapping("/my")
    public R<List<Map<String, Object>>> myAppeals() {
        return R.ok(reviewAppealService.myAppeals());
    }
}