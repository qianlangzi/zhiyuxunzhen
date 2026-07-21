package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Data
@Builder
public class StudentLearningOverviewVO {
    /** OSCE 各维度平均分；没有已评分会话时为空。 */
    private Map<String, Integer> abilityScores;
    private List<ActivityDay> activityDays;
    private Integer completedSessionCount;

    @Data
    @Builder
    public static class ActivityDay {
        private LocalDate date;
        private Integer completedCount;
    }
}
