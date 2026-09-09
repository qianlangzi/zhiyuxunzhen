package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 教师端-基础题管理列表项（含审核状态）
 */
@Data
@Builder
public class TeacherQuestionVO {

    private Long id;

    /** 统一题号（如 ST000001） */
    private String questionNo;

    private String questionType;

    private String department;

    private String knowledgeTag;

    private String title;

    private List<String> options;

    private String answer;

    private String explanation;

    /** 1简单 2标准 3困难 */
    private Integer difficulty;

    private Long sourceTextbookId;

    private String sourceTextbookTitle;

    /** 0未提交 1待审核 2通过 3驳回 */
    private Integer adminAuditStatus;

    /** 管理端驳回复核意见 */
    private String rejectReason;

    /** 提交人姓名（全部题库展示作者用） */
    private String creatorName;

    private LocalDateTime createdAt;
}