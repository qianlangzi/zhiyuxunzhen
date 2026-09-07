package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 学生错题本表（PRD 8.8）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("student_mistakes")
public class StudentMistakes extends BaseEntity {

    private Long studentId;

    private Long sessionId;

    private Long caseId;

    /** 关联基础题库题目（刷题错题时非空；caseId 则用于病例错题） */
    private Long questionId;

    /** diagnosis / history / exam / record / communication / practice */
    private String mistakeType;

    private String knowledgeTag;

    private String studentAnswer;

    private String standardAnswer;

    /** 关键证据和脱轨节点 JSON */
    private String evidenceJson;

    /** 错题 AI 归因结果 JSON（rootCause/explanation/recommendedTags/practiceHint/source/status） */
    private String aiAnalysisJson;

    /** 0未复习 1已复习 2已掌握 */
    private Integer resolvedStatus;

    /** 进入错题本后连续答对次数（不区分 mistakeType；刷题错题达到阈值判已掌握） */
    private Integer consecutiveCorrect;

    /** 进入错题本后累计答错次数 */
    private Integer wrongCount;

    /** 0普通 1需加强（连续答错>=2，反复做错的薄弱题） */
    private Integer focusFlag;
}
