package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.dto.RejectDTO;
import com.zhiyu.vo.TeacherAuditDetailVO;
import com.zhiyu.vo.TeacherAuditVO;
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
 * 教师资质审核（PRD 4.14）
 */
@Tag(name = "管理端-教师资质审核")
@RestController
@RequestMapping("/api/v1/admin/teacher-audits")
@RequiredArgsConstructor
public class TeacherAuditController {

    private final AdminService adminService;

    @Operation(summary = "教师资质审核列表")
    @GetMapping
    public R<PageResult<TeacherAuditVO>> list(PageParam param,
                                              @RequestParam(required = false) Integer auditStatus) {
        return R.ok(adminService.teacherAuditList(param, auditStatus));
    }

    @Operation(summary = "教师资质审核详情")
    @GetMapping("/{userId}/detail")
    public R<TeacherAuditDetailVO> detail(@PathVariable Long userId) {
        return R.ok(adminService.teacherAuditDetail(userId));
    }

    @Operation(summary = "审核通过教师资质")
    @PostMapping("/{userId}/approve")
    public R<Void> approve(@PathVariable Long userId) {
        adminService.approveTeacher(userId);
        return R.ok();
    }

    @Operation(summary = "驳回教师资质")
    @PostMapping("/{userId}/reject")
    public R<Void> reject(@PathVariable Long userId, @Valid @RequestBody RejectDTO dto) {
        adminService.rejectTeacher(userId, dto);
        return R.ok();
    }
}
