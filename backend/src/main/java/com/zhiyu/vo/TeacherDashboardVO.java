package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * 教师学情看板概览 VO
 */
@Data
@Builder
public class TeacherDashboardVO {
    private Double completionRate;
    private Double avgOsceScore;
    private Double reviewEfficiency;
    private Double overExamRate;
    private Map<String, Integer> osceDimensionScores;
    private List<CommonMistake> commonMistakes;

    /** 教师首页工作台：待教师复核的实例数（status=4） */
    private Integer pendingReview;
    /** 教师首页工作台：进行中的作业数 */
    private Integer activeAssignments;
    /** 教师首页工作台：本人病例数 */
    private Integer myCases;
    /** 教师首页工作台：被授权班级数 */
    private Integer classCount;
    /** 教师首页工作台：病例广场累计引用次 */
    private Integer marketRefs;
    /** 教师首页工作台：病例广场平均评分 */
    private Double marketRating;

    @Data
    @Builder
    public static class CommonMistake {
        private String type;
        private String description;
        private Integer count;
    }
}