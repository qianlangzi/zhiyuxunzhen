package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 病例审核列表项（PRD 4.15）
 */
@Data
@Builder
public class CaseAuditVO {

    private Long caseId;

    private String title;

    private String department;

    /** 1简单 2标准 3困难 */
    private Integer difficulty;

    private Long creatorId;

    private String creatorName;

    /** 1待审核 2通过 3驳回 */
    private Integer auditStatus;

    private LocalDateTime createdAt;
}
