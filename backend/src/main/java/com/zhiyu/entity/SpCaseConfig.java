package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

/**
 * 病例配置表（PRD 8.2）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("sp_case_config")
public class SpCaseConfig extends BaseEntity {

    private Long creatorId;

    /** 引用来源病例ID，自建为空 */
    private Long sourceCaseId;

    private String title;

    private String department;

    /** 1简单 2标准 3困难 */
    private Integer difficulty;

    /** 患者画像 JSON：年龄/性别/职业/主诉/性格等 */
    private String patientProfile;

    private String hiddenDisease;

    /** 标准问诊、检查、诊断路径 JSON */
    private String standardPathJson;

    /** 检查项目、结果、费用、是否关键 JSON */
    private String presetExams;

    /** 知识点标签 JSON 数组 */
    private String knowledgeTags;

    /** 是否发布至病例广场 */
    private Boolean isPublic;

    private Integer referenceCount;

    private BigDecimal ratingAvg;

    /** 0未提交 1待审 2通过 3驳回 4下架 */
    private Integer adminAuditStatus;

    private Integer version;

    /** 0草稿 1已发布 */
    private Integer status;

    @TableLogic
    @TableField(value = "is_deleted")
    private Integer isDeleted;
}
