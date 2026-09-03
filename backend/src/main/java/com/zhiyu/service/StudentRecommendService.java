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

    /**
     * 组装学生「事实快照」供学习路径 / AI 学伴等个性化 Agent 使用（P0-1 学习路径真实化）
     * 返回结构：weaknesses / mistakes / learnedChapters / candidateTextbooks / candidateQuestions /
     * candidateCases / student{realName,username,schoolName,grade,className,role} /
     * progress[{label,value}]（已刷基础题/已完成作业/完成问诊训练/完成每日一例/读完教材章节/已坚持学习天数）
     */
    java.util.Map<String, Object> buildLearningFacts();

    /**
     * 薄弱点学情诊断（P0-3）：统计兜底 + AI 归因合并，供推荐页「AI 诊断」区块展示
     * 返回结构：overall / items[{knowledgeTag, statScore, evidenceCount, rootCause, suggestion, source}] / source / status
     */
    java.util.Map<String, Object> aiDiagnosis();
}