package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeachingClassService;
import com.zhiyu.service.dto.TeachingClassCreateDTO;
import com.zhiyu.service.dto.ClassSortDTO;
import com.zhiyu.vo.TeachingClassMemberVO;
import com.zhiyu.vo.TeachingClassVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 教师端-班级管理（自建班级 / 重命名 / 解散 / 成员 / 邀请信息）
 * 注意：PermissionInterceptor 中 /api/v1/teacher/** 要求教师角色且资质已通过。
 */
@Tag(name = "教师-班级管理")
@RestController
@RequestMapping("/api/v1/teacher/classes")
@RequiredArgsConstructor
public class TeacherClassController {

    private final TeachingClassService teachingClassService;

    @Operation(summary = "我的班级列表（自建 + 授权，含邀请码）")
    @GetMapping
    public R<List<TeachingClassVO>> list() {
        return R.ok(teachingClassService.myClasses());
    }

    @Operation(summary = "班级详情（含邀请码）")
    @GetMapping("/{id}")
    public R<TeachingClassVO> detail(@PathVariable Long id) {
        return R.ok(teachingClassService.detail(id));
    }

    @Operation(summary = "新建班级")
    @PostMapping
    public R<TeachingClassVO> create(@Valid @RequestBody TeachingClassCreateDTO req) {
        return R.ok(teachingClassService.create(req));
    }

    @Operation(summary = "重命名班级（仅创建教师）")
    @PutMapping("/{id}")
    public R<TeachingClassVO> rename(@PathVariable Long id,
                                     @Valid @RequestBody TeachingClassCreateDTO req) {
        return R.ok(teachingClassService.rename(id, req));
    }

    @Operation(summary = "解散班级（仅创建教师）")
    @DeleteMapping("/{id}")
    public R<Void> dissolve(@PathVariable Long id) {
        teachingClassService.dissolve(id);
        return R.ok();
    }

    @Operation(summary = "班级成员（学生）列表")
    @GetMapping("/{id}/members")
    public R<List<TeachingClassMemberVO>> members(@PathVariable Long id) {
        return R.ok(teachingClassService.members(id));
    }

    @Operation(summary = "批量保存班级排序（按传入 id 顺序持久化）")
    @PostMapping("/sort")
    public R<Void> sort(@RequestBody ClassSortDTO dto) {
        teachingClassService.sortOrder(dto.getClassIds());
        return R.ok();
    }
}