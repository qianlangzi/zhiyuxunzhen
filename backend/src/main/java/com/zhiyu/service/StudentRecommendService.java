package com.zhiyu.service;

import com.zhiyu.vo.RecommendationVO;
import com.zhiyu.vo.SearchResultVO;

import java.util.List;

/**
 * 学生端智能检索服务：基于薄弱知识点推荐基础题 + 教材，及全局检索
 */
public interface StudentRecommendService {

    /**
     * 针对单个薄弱知识点的推荐（基础题 + 教材）
     */
    RecommendationVO recommendFor(String knowledgeTag);

    /**
     * 针对当前学生全部薄弱知识点的推荐（按掌握度优先）
     */
    List<RecommendationVO> recommendForAllWeaknesses();

    /**
     * 全局检索（教材 + 基础题 + 病例）
     */
    SearchResultVO search(String keyword);
}