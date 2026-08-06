package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 薄弱知识点推荐结果 VO（推荐基础题 + 对应教材）
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
}