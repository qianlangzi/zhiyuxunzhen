package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 管理端-基础题审核列表项（PRD 4.15 扩展：题库审核）
 */
@Data
@Builder
public class QuestionAuditVO {

    private Long questionId;

    private String questionType;

    private String department;

    private String knowledgeTag;

    private String title;

    /** 1简单 2标准 3困难 */
    private Integer difficulty;

    private Long submitterId;

    private String submitterName;

    /** 1待审核 2通过 3驳回 */
    private Integer auditStatus;

    private LocalDateTime createdAt;
}