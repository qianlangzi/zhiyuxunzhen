package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherProfileService;
import com.zhiyu.service.dto.TeacherAuditSubmitDTO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 教师端-个人资质接口（PRD 9.1）
 * 教师主动提交资质认证材料，audit_status: 0/3 → 1
 */
@Tag(name = "教师-个人资质")
@RestController
@RequestMapping("/api/v1/teacher/profile")
@RequiredArgsConstructor
public class TeacherProfileController {

    private final TeacherProfileService teacherProfileService;

    @Operation(summary = "提交资质认证材料")
    @PostMapping("/audit-submit")
    public R<Void> submitAudit(@Valid @RequestBody TeacherAuditSubmitDTO dto) {
        teacherProfileService.submitAudit(dto);
        return R.ok();
    }
}
