package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 基础题训练统计 VO
 */
@Data
@Builder
public class PracticeStatsVO {

    private long totalCount;
    private long totalAnswered;
    private long correctCount;

    /** 总体正确率 0.00 ~ 1.00 */
    private double accuracy;

    private List<ByKnowledgeTag> byKnowledgeTag;

    @Data
    @Builder
    public static class ByKnowledgeTag {
        private String knowledgeTag;
        private long total;
        private long answered;
        private long correct;
        private double accuracy;
    }
}