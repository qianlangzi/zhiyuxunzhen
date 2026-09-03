package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 作业任务项信息（教师端/学生端通用）
 */
@Data
@Builder
public class AssignmentItemVO {
    private Long id;
    private Long assignmentId;
    /** CASE / PRACTICE / READING */
    private String itemType;
    private String title;
    private Integer sortOrder;

    /** CASE:病例ID + 病例标题 */
    private Long caseId;
    private String caseTitle;

    /** PRACTICE:题目ID列表 + 数量 */
    private List<Long> questionIds;
    private Integer questionCount;

    /** READING:教材ID + 教材标题 + 阅读范围 */
    private Long textbookId;
    private String textbookTitle;
    private String readingScope;
}
