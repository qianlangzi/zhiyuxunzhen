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
    /** 刷题错题关联的题目 id（caseId 为空时存在） */
    private Long questionId;
    /** 刷题错题对应的题目题干 */
    private String questionTitle;
    private Long sessionId;
    /** diagnosis / history / exam / record / communication / practice */
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
    /** 进入错题本后连续答对次数 */
    private Integer consecutiveCorrect;
    /** 进入错题本后累计答错次数 */
    private Integer wrongCount;
    /** 0普通 1需加强（连续答错>=2） */
    private Integer focusFlag;
    private LocalDateTime createdAt;
}
