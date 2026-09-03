package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentEvaluationService;
import com.zhiyu.vo.OsceHistoryVO;
import com.zhiyu.vo.SessionEvaluationVO;
import com.zhiyu.vo.ThinkingTreeVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 学生会话评估接口
 */
@Tag(name = "学生会话评估")
@RestController
@RequestMapping("/api/v1/student/evaluations")
@RequiredArgsConstructor
public class StudentEvaluationController {

    private final StudentEvaluationService studentEvaluationService;

    @Operation(summary = "OSCE 考核历史记录列表（已完成会话）")
    @GetMapping("/history")
    public R<List<OsceHistoryVO>> history() {
        return R.ok(studentEvaluationService.history());
    }

    @Operation(summary = "获取会话 OSCE 评估结果")
    @GetMapping("/{sessionId}")
    public R<SessionEvaluationVO> getEvaluation(@PathVariable Long sessionId) {
        return R.ok(studentEvaluationService.getEvaluation(sessionId));
    }

    @Operation(summary = "获取思维树数据")
    @GetMapping("/{sessionId}/thinking-tree")
    public R<ThinkingTreeVO> getThinkingTree(@PathVariable Long sessionId) {
        return R.ok(studentEvaluationService.getThinkingTree(sessionId));
    }
}