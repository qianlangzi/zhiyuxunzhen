package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 教师预览病例配置（含隐藏疾病、标准路径）
 */
@Data
@Builder
public class CasePreviewVO {
    private Long id;
    private String title;
    private String department;
    private Integer difficulty;
    private String patientProfile;
    private String hiddenDisease;
    private String standardPathJson;
    private String presetExams;
    private String knowledgeTags;
    private Boolean isPublic;
    private Long sourceCaseId;
    private Integer referenceCount;
    private BigDecimal ratingAvg;
    private Integer adminAuditStatus;
    private Integer version;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
