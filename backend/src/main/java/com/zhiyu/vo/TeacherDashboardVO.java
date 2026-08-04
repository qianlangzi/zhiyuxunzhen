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

    @Data
    @Builder
    public static class CommonMistake {
        private String type;
        private String description;
        private Integer count;
    }
}