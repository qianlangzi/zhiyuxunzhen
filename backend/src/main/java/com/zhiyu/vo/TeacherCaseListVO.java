package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 教师病例列表项
 */
@Data
@Builder
public class TeacherCaseListVO {
    private Long id;
    /** 统一病例号（如 BL000001） */
    private String caseNo;
    private String title;
    private String department;
    private Integer difficulty;
    /** 0草稿 1已发布 */
    private Integer status;
    /** 0未提交 1待审 2通过 3驳回 4下架 */
    private Integer adminAuditStatus;
    private Integer referenceCount;
    private BigDecimal ratingAvg;
    private Boolean isPublic;
    private LocalDateTime createdAt;
}
