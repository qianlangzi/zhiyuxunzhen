package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentRecommendService;
import com.zhiyu.vo.RecommendationVO;
import com.zhiyu.vo.SearchResultVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 学生端-智能检索接口（薄弱知识点推荐 + 全局检索）
 */
@Tag(name = "学生-智能检索")
@RestController
@RequestMapping("/api/v1/student/recommend")
@RequiredArgsConstructor
public class StudentRecommendController {

    private final StudentRecommendService recommendService;

    @Operation(summary = "针对单个薄弱知识点的推荐（基础题 + 教材）")
    @GetMapping("/weakness")
    public R<RecommendationVO> recommendFor(@RequestParam String knowledgeTag) {
        return R.ok(recommendService.recommendFor(knowledgeTag));
    }

    @Operation(summary = "当前学生全部薄弱知识点的推荐列表")
    @GetMapping("/weaknesses")
    public R<List<RecommendationVO>> recommendAll() {
        return R.ok(recommendService.recommendForAllWeaknesses());
    }

    @Operation(summary = "全局检索（教材 + 基础题 + 病例）")
    @GetMapping("/search")
    public R<SearchResultVO> search(@RequestParam String keyword) {
        return R.ok(recommendService.search(keyword));
    }
}