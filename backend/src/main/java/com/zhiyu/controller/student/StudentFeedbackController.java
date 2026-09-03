package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.StudentFeedback;
import com.zhiyu.service.StudentFeedbackService;
import com.zhiyu.service.dto.ActionTrackRequest;
import com.zhiyu.service.dto.FeedbackSubmitRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-体验反馈与试用埋点（P2-3 真实用户数据）
 */
@Tag(name = "学生-反馈埋点")
@RestController
@RequestMapping("/api/v1/student")
@RequiredArgsConstructor
public class StudentFeedbackController {

    private final StudentFeedbackService studentFeedbackService;

    @Operation(summary = "提交体验反馈")
    @PostMapping("/feedback")
    public R<Long> submit(@Valid @RequestBody FeedbackSubmitRequest req) {
        return R.ok(studentFeedbackService.submit(req.getCategory(), req.getRating(), req.getContent()));
    }

    @Operation(summary = "我的反馈列表")
    @GetMapping("/feedback")
    public R<PageResult<StudentFeedback>> list(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize) {
        return R.ok(studentFeedbackService.myFeedback(pageNum, pageSize));
    }

    @Operation(summary = "关键动作埋点（试用记录）")
    @PostMapping("/track")
    public R<Void> track(@Valid @RequestBody ActionTrackRequest req) {
        studentFeedbackService.track(req.getAction(), req.getDetail());
        return R.ok();
    }
}
