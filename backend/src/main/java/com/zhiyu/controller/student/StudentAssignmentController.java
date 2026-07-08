package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.StudentAssignmentService;
import com.zhiyu.service.dto.SubmitRecordDTO;
import com.zhiyu.vo.StudentAssignmentVO;
import com.zhiyu.vo.SubmitRecordResultVO;
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

/**
 * 学生端-作业接口（PRD 4.4 / 5.3 / 9.1）
 */
@Tag(name = "学生-作业")
@RestController
@RequestMapping("/api/v1/student/assignments")
@RequiredArgsConstructor
public class StudentAssignmentController {

    private final StudentAssignmentService studentAssignmentService;

    @Operation(summary = "我的作业列表")
    @GetMapping("/my")
    public R<PageResult<StudentAssignmentVO>> my(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize) {
        return R.ok(studentAssignmentService.myAssignments(pageNum, pageSize));
    }

    @Operation(summary = "提交大病历（格式盾牌校验）")
    @PostMapping("/{id}/submit-record")
    public R<SubmitRecordResultVO> submitRecord(@PathVariable Long id, @Valid @RequestBody SubmitRecordDTO req) {
        return R.ok(studentAssignmentService.submitRecord(id, req));
    }
}
