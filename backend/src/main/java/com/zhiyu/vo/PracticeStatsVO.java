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

    /** 按科室（模块）聚合的正确率与做题数 */
    private List<ByDepartment> byDepartment;

    @Data
    @Builder
    public static class ByKnowledgeTag {
        private String knowledgeTag;
        private long total;
        private long answered;
        private long correct;
        private double accuracy;
    }

    @Data
    @Builder
    public static class ByDepartment {
        private String department;
        private long total;
        private long answered;
        private long correct;
        private double accuracy;
    }
}