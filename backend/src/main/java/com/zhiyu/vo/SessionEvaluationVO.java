package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * 会话 OSCE 评估结果 VO
 */
@Data
@Builder
public class SessionEvaluationVO {
    private Long sessionId;
    private Long caseId;
    private Map<String, Integer> osceScores;
    private List<String> strengths;
    private List<String> improvements;
    private Integer totalScore;
}