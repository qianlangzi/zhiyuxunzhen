package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.ReviewAppealService;
import com.zhiyu.service.dto.ReviewAppealHandleDTO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 教师端-批阅申诉处理（PRD 4.4.5 / 5.3）
 * 教师查看所布置作业的申诉，处理（改分/回复）或驳回。
 */
@Tag(name = "教师-批阅申诉")
@RestController
@RequestMapping("/api/v1/teacher/reviews/appeals")
@RequiredArgsConstructor
public class TeacherAppealController {

    private final ReviewAppealService reviewAppealService;

    @Operation(summary = "我的作业申诉列表（status 为空=全部/1待处理 按实际状态过滤）")
    @GetMapping
    public R<List<Map<String, Object>>> list(@RequestParam(required = false) Integer status) {
        return R.ok(reviewAppealService.teacherAppeals(status));
    }

    @Operation(summary = "处理申诉：改分/回复 或 驳回")
    @PostMapping("/{appealId}/handle")
    public R<Void> handle(@PathVariable Long appealId,
                          @Valid @RequestBody ReviewAppealHandleDTO dto) {
        reviewAppealService.handle(appealId, dto.getStatus(), dto.getReply(), dto.getNewScore());
        return R.ok();
    }
}