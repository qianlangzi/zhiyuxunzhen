package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.StudentAssignmentService;
import com.zhiyu.service.dto.PracticeSubmitDTO;
import com.zhiyu.service.dto.SubmitRecordDTO;
import com.zhiyu.vo.PracticeSubmitResultVO;
import com.zhiyu.vo.StudentAssignmentDetailVO;
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

    @Operation(summary = "待办作业列表（仅未完成：未开始/问诊中/格式打回）")
    @GetMapping("/todo")
    public R<PageResult<StudentAssignmentVO>> todo(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize) {
        return R.ok(studentAssignmentService.todoAssignments(pageNum, pageSize));
    }

    @Operation(summary = "作业实例详情（查看作业 + 提交大病历）")
    @GetMapping("/{id}")
    public R<StudentAssignmentDetailVO> detail(@PathVariable Long id) {
        return R.ok(studentAssignmentService.detail(id));
    }

    @Operation(summary = "提交大病历（格式盾牌校验）")
    @PostMapping("/{id}/submit-record")
    public R<SubmitRecordResultVO> submitRecord(
            @PathVariable Long id,
            @RequestParam(required = false) Long itemProgressId,
            @Valid @RequestBody SubmitRecordDTO req) {
        return R.ok(studentAssignmentService.submitRecord(id, itemProgressId, req));
    }

    @Operation(summary = "提交练习任务项答案（客观题自动判分）")
    @PostMapping("/{id}/items/{itemProgressId}/submit-practice")
    public R<PracticeSubmitResultVO> submitPractice(
            @PathVariable Long id,
            @PathVariable Long itemProgressId,
            @Valid @RequestBody PracticeSubmitDTO req) {
        return R.ok(studentAssignmentService.submitPractice(id, itemProgressId, req));
    }

    @Operation(summary = "标记阅读任务项完成")
    @PostMapping("/{id}/items/{itemProgressId}/complete-reading")
    public R<PracticeSubmitResultVO> completeReading(
            @PathVariable Long id,
            @PathVariable Long itemProgressId) {
        return R.ok(studentAssignmentService.completeReading(id, itemProgressId));
    }
}
