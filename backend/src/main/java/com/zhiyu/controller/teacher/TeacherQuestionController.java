package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.PracticeQuestionService;
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

import java.util.List;

/**
 * 教师端-基础题库录入（提交管理端审核）
 */
@Tag(name = "教师-基础题库")
@RestController
@RequestMapping("/api/v1/teacher/questions")
@RequiredArgsConstructor
public class TeacherQuestionController {

    private final TeacherQuestionService teacherQuestionService;
    private final PracticeQuestionService practiceQuestionService;

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

    @Operation(summary = "全部基础题库（含所有人的题目，支持审核状态/科室/知识点/难度/题型筛选 + 关键字搜索）")
    @GetMapping("/all")
    public R<PageResult<TeacherQuestionVO>> allList(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) Integer adminAuditStatus,
            @RequestParam(required = false) String department,
            @RequestParam(required = false) String knowledgeTag,
            @RequestParam(required = false) Integer difficulty,
            @RequestParam(required = false) String questionType,
            @RequestParam(required = false) String keyword) {
        return R.ok(teacherQuestionService.allQuestions(pageNum, pageSize, adminAuditStatus,
                department, knowledgeTag, difficulty, questionType, keyword));
    }

    @Operation(summary = "题库科室列表（与学生端同源，带进程内缓存）")
    @GetMapping("/departments")
    public R<List<String>> departments() {
        return R.ok(practiceQuestionService.departments());
    }

    @Operation(summary = "题库知识点列表（与学生端同源，带进程内缓存）")
    @GetMapping("/knowledge-tags")
    public R<List<String>> knowledgeTags() {
        return R.ok(practiceQuestionService.knowledgeTags());
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