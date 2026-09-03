package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.TeacherQuestionService;
import com.zhiyu.service.dto.TeacherQuestionCreateDTO;
import com.zhiyu.vo.TeacherQuestionVO;
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

/**
 * 教师端-基础题库录入（提交管理端审核）
 */
@Tag(name = "教师-基础题库")
@RestController
@RequestMapping("/api/v1/teacher/questions")
@RequiredArgsConstructor
public class TeacherQuestionController {

    private final TeacherQuestionService teacherQuestionService;

    @Operation(summary = "创建基础题（草稿）")
    @PostMapping
    public R<Long> create(@Valid @RequestBody TeacherQuestionCreateDTO req) {
        return R.ok(teacherQuestionService.create(req));
    }

    @Operation(summary = "更新基础题（草稿/驳回态）")
    @PutMapping("/{id}")
    public R<Void> update(@PathVariable Long id, @Valid @RequestBody TeacherQuestionCreateDTO req) {
        teacherQuestionService.update(id, req);
        return R.ok();
    }

    @Operation(summary = "提交审核")
    @PostMapping("/{id}/submit")
    public R<Void> submit(@PathVariable Long id) {
        teacherQuestionService.submit(id);
        return R.ok();
    }

    @Operation(summary = "删除基础题（草稿/驳回态）")
    @DeleteMapping("/{id}")
    public R<Void> delete(@PathVariable Long id) {
        teacherQuestionService.delete(id);
        return R.ok();
    }

    @Operation(summary = "我的基础题列表（含审核状态）")
    @GetMapping
    public R<PageResult<TeacherQuestionVO>> list(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) Integer adminAuditStatus) {
        return R.ok(teacherQuestionService.myQuestions(pageNum, pageSize, adminAuditStatus));
    }

    @Operation(summary = "全部基础题库（含所有人的题目，可按审核状态筛选）")
    @GetMapping("/all")
    public R<PageResult<TeacherQuestionVO>> allList(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) Integer adminAuditStatus) {
        return R.ok(teacherQuestionService.allQuestions(pageNum, pageSize, adminAuditStatus));
    }

    @Operation(summary = "题库公开详情（全部题库中查看他人题目）")
    @GetMapping("/public/{id}")
    public R<TeacherQuestionVO> detailPublic(@PathVariable Long id) {
        return R.ok(teacherQuestionService.detailPublic(id));
    }

    @Operation(summary = "我的基础题详情")
    @GetMapping("/{id}")
    public R<TeacherQuestionVO> detail(@PathVariable Long id) {
        return R.ok(teacherQuestionService.detail(id));
    }
}