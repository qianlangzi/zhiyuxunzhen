package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.ClassMaterialService;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

/**
 * 教师端-班级管理（自建班级 / 重命名 / 解散 / 成员 / 邀请信息 / 班级资料库）
 * 注意：PermissionInterceptor 中 /api/v1/teacher/** 要求教师角色且资质已通过。
 */
@Tag(name = "教师-班级管理")
@RestController
@RequestMapping("/api/v1/teacher/classes")
@RequiredArgsConstructor
public class TeacherClassController {

    private final TeachingClassService teachingClassService;
    private final ClassMaterialService classMaterialService;

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

    // ---------------- 班级资料库 ----------------

    @Operation(summary = "班级资料列表（上传 + 教材引用，按时间倒序）")
    @GetMapping("/{classId}/materials")
    public R<List<Map<String, Object>>> materials(@PathVariable Long classId) {
        return R.ok(classMaterialService.teacherList(classId));
    }

    @Operation(summary = "上传班级资料（pdf/ppt/pptx/doc/docx/txt/epub/mp4/mp3/图片，≤200MB）")
    @PostMapping("/{classId}/materials")
    public R<Long> uploadMaterial(@PathVariable Long classId,
                                  @RequestParam(value = "title", required = false) String title,
                                  @RequestParam(value = "durationSec", required = false) Integer durationSec,
                                  @RequestParam("file") MultipartFile file) {
        return R.ok(classMaterialService.upload(classId, title, durationSec, file));
    }

    @Operation(summary = "引用教材库教材到班级资料")
    @PostMapping("/{classId}/materials/textbook")
    public R<Long> referenceTextbook(@PathVariable Long classId,
                                     @RequestBody Map<String, Long> body) {
        Long textbookId = body.get("textbookId");
        if (textbookId == null) {
            throw new com.zhiyu.common.exception.BizException(
                    com.zhiyu.common.constant.ResultCode.BAD_REQUEST, "textbookId 不能为空");
        }
        return R.ok(classMaterialService.referenceTextbook(classId, textbookId));
    }

    @Operation(summary = "移除班级资料")
    @DeleteMapping("/{classId}/materials/{materialId}")
    public R<Void> removeMaterial(@PathVariable Long classId, @PathVariable Long materialId) {
        classMaterialService.remove(classId, materialId);
        return R.ok();
    }
}