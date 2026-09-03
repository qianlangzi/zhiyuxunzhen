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

    /** diagnosis / history / exam / record / communication */
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
}
