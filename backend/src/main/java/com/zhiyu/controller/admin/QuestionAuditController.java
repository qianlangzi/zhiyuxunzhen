package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.dto.RejectDTO;
import com.zhiyu.vo.QuestionAuditVO;
import com.zhiyu.vo.TeacherQuestionVO;
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
 * 管理端-基础题审核（题库闭环：教师提交 → 管理员审核 → 学生可见）
 */
@Tag(name = "管理端-基础题审核")
@RestController
@RequestMapping("/api/v1/admin/question-audits")
@RequiredArgsConstructor
public class QuestionAuditController {

    private final AdminService adminService;

    @Operation(summary = "基础题审核列表（可按审核状态筛选：1待审核 2通过 3驳回）")
    @GetMapping
    public R<PageResult<QuestionAuditVO>> list(PageParam param,
                                              @RequestParam(required = false) Integer auditStatus) {
        return R.ok(adminService.questionAuditList(param, auditStatus));
    }

    @Operation(summary = "基础题审核详情（题干/答案/解析）")
    @GetMapping("/{questionId}/detail")
    public R<TeacherQuestionVO> detail(@PathVariable Long questionId) {
        return R.ok(adminService.questionAuditDetail(questionId));
    }

    @Operation(summary = "基础题审核通过")
    @PostMapping("/{questionId}/approve")
    public R<Void> approve(@PathVariable Long questionId) {
        adminService.approveQuestion(questionId);
        return R.ok();
    }

    @Operation(summary = "基础题审核驳回（附复核意见）")
    @PostMapping("/{questionId}/reject")
    public R<Void> reject(@PathVariable Long questionId, @Valid @RequestBody RejectDTO dto) {
        adminService.rejectQuestion(questionId, dto);
        return R.ok();
    }
}