package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 学生错题本列表项（PRD 4.11）
 */
@Data
@Builder
public class MistakeVO {
    private Long id;
    private Long caseId;
    private String caseTitle;
    private Long sessionId;
    /** diagnosis / history / exam / record / communication */
    private String mistakeType;
    private String knowledgeTag;
    private String studentAnswer;
    private String standardAnswer;
    /** 关键证据和脱轨节点 JSON */
    private String evidenceJson;
    /** 错题 AI 归因结果（rootCause/explanation/recommendedTags/practiceHint/source/status），未分析为 null */
    private Object aiAnalysis;
    /** 归因状态：SUCCESS / DEGRADED / null（未分析） */
    private String aiStatus;
    /** 0未复习 1已复习 2已掌握 */
    private Integer resolvedStatus;
    private LocalDateTime createdAt;
}
