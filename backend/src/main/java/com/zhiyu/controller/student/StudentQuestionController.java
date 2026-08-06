package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.PracticeQuestionService;
import com.zhiyu.service.dto.PracticeAnswerDTO;
import com.zhiyu.vo.PracticeQuestionVO;
import com.zhiyu.vo.PracticeStatsVO;
import com.zhiyu.vo.SubmitResultVO;
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
 * 学生端-基础题训练接口
 */
@Tag(name = "学生-基础题训练")
@RestController
@RequestMapping("/api/v1/student/questions")
@RequiredArgsConstructor
public class StudentQuestionController {

    private final PracticeQuestionService practiceQuestionService;

    @Operation(summary = "基础题分页列表（支持知识点/难度/题型筛选）")
    @GetMapping
    public R<PageResult<PracticeQuestionVO>> page(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String knowledgeTag,
            @RequestParam(required = false) Integer difficulty,
            @RequestParam(required = false) String questionType) {
        return R.ok(practiceQuestionService.page(pageNum, pageSize, knowledgeTag, difficulty, questionType));
    }

    @Operation(summary = "题目详情")
    @GetMapping("/{id}")
    public R<PracticeQuestionVO> detail(@PathVariable Long id) {
        return R.ok(practiceQuestionService.detail(id));
    }

    @Operation(summary = "提交答案并判题，记录练习记录")
    @PostMapping("/submit")
    public R<SubmitResultVO> submit(@Valid @RequestBody PracticeAnswerDTO dto) {
        return R.ok(practiceQuestionService.submit(dto));
    }

    @Operation(summary = "我的训练统计")
    @GetMapping("/stats")
    public R<PracticeStatsVO> stats() {
        return R.ok(practiceQuestionService.stats());
    }
}