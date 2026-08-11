package com.zhiyu.service;

/**
 * 薄弱知识点推算服务（掌握度统计算法）
 *
 * 从学生错题本 + 基础题刷题记录中，用确定性统计算法反推每个知识点的掌握度，
 * 并 upsert 回填 student_weakness 表。设计上不依赖 LLM，保证结果稳定、可解释、可复现。
 *
 * 掌握度 weaknessScore ∈ (0, 1)，越高越扎实、越低越薄弱；
 * 调用方按 weaknessScore 升序即得到"最薄弱优先"的推荐顺序。
 */
public interface WeaknessAnalysisService {

    /**
     * 重算某学生的全部薄弱知识点掌握度并回填。
     * 触发时机：错题本同步、基础题刷题提交后调用。
     */
    void refreshForStudent(Long studentId);
}