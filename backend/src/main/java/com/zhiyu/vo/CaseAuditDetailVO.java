package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 病例审核详情（PRD 4.15 扩展：查看详情）
 * 供审核人/管理员查看病例的完整内容（含各 JSON 配置原文，前端负责格式化展示）。
 */
@Data
@Builder
public class CaseAuditDetailVO {

    private Long caseId;

    private String title;

    private String department;

    /** 1简单 2标准 3困难 */
    private Integer difficulty;

    private Long creatorId;

    private String creatorName;

    /** 患者画像 JSON：年龄/性别/职业/主诉/性格等 */
    private String patientProfile;

    /** 隐藏疾病（需 AI 追问发现的正确答案） */
    private String hiddenDisease;

    /** 知识点标签 JSON 数组 */
    private String knowledgeTags;

    /** 检查项目/结果/费用/是否关键 JSON */
    private String presetExams;

    /** 标准问诊、检查、诊断路径 JSON */
    private String standardPath;

    /** 标准答案 / 诊断要点 */
    private String referenceAnswer;

    /** 评分要点 JSON 数组 [{label,fullMark,criteria,deduct}] */
    private String scoringPoints;

    /** 引用来源病例ID，自建为空 */
    private Long sourceCaseId;

    /** 1待审核 2通过 3驳回 */
    private Integer adminAuditStatus;

    private LocalDateTime createdAt;
}