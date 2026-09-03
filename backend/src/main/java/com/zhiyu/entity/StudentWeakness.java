package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 薄弱知识点表（PRD 8.9）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("student_weakness")
public class StudentWeakness extends BaseEntity {

    private Long studentId;

    private String knowledgeTag;

    /** 掌握度 0.00 ~ 1.00，越高越扎实、越低越薄弱（推荐按升序取最薄弱） */
    private BigDecimal weaknessScore;

    private Integer evidenceCount;

    /** 推荐路径 JSON */
    private String recommendedPathJson;

    private LocalDateTime lastUpdated;
}
