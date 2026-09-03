package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 薄弱知识点推荐结果 VO（推荐基础题 + 对应教材 + AI 智能建议）
 */
@Data
@Builder
public class RecommendationVO {
    /** 薄弱知识点 */
    private String knowledgeTag;

    /** 推荐的基础题 */
    private List<PracticeQuestionVO> questions;

    /** 推荐的教材 */
    private List<TextbookVO> textbooks;

    /** AI 整体补救建议（1-3 句） */
    private String aiAdvice;

    /** AI 排序的优先复习知识点 */
    private List<String> aiPriority;

    /** AI 刷题方向与难度进阶安排 */
    private String aiStudyPlan;

    /** AI 对近期错题的针对性提示 */
    private String aiMistakesNote;
}