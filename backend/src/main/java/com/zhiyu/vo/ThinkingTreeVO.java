package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 临床思维树 VO
 */
@Data
@Builder
public class ThinkingTreeVO {
    private Long sessionId;
    private Double totalExamCost;
    private List<SymptomItem> symptoms;
    private List<ReasoningItem> reasoning;
    private String socraticPrompt;

    @Data
    @Builder
    public static class SymptomItem {
        private String name;
        private String description;
        private String evidence;
    }

    @Data
    @Builder
    public static class ReasoningItem {
        private String step;
        private String content;
        private Boolean correct;
    }
}