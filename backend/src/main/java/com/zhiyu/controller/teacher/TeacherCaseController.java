package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.TeacherCaseService;
import com.zhiyu.service.dto.CaseCreateDTO;
import com.zhiyu.service.dto.CaseUpdateDTO;
import com.zhiyu.vo.CasePreviewVO;
import com.zhiyu.vo.TeacherCaseListVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 教师端-病例管理接口（PRD 4.1 / 9.1）
 */
@Tag(name = "教师-病例管理")
@RestController
@RequestMapping("/api/v1/teacher/cases")
@RequiredArgsConstructor
public class TeacherCaseController {

    private final TeacherCaseService teacherCaseService;

    @Operation(summary = "创建病例")
    @PostMapping
    public R<Long> create(@Valid @RequestBody CaseCreateDTO req) {
        return R.ok(teacherCaseService.create(req));
    }

    @Operation(summary = "更新病例")
    @PutMapping("/{id}")
    public R<Void> update(@PathVariable Long id, @Valid @RequestBody CaseUpdateDTO req) {
        teacherCaseService.update(id, req);
        return R.ok();
    }

    @Operation(summary = "我的病例列表（分页）")
    @GetMapping
    public R<PageResult<TeacherCaseListVO>> list(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) String department) {
        return R.ok(teacherCaseService.myCases(pageNum, pageSize, title, department));
    }

    @Operation(summary = "预览病例配置（含隐藏疾病、标准路径）")
    @GetMapping("/{id}/preview")
    public R<CasePreviewVO> preview(@PathVariable Long id) {
        return R.ok(teacherCaseService.preview(id));
    }
}
