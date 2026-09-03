package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

/**
 * 学情预警记录（助教：学情精准诊断）
 * Rule-first 规则引擎扫描生成，AI 生成干预建议（缓存）。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("student_alert")
public class StudentAlert extends BaseEntity {

    private Long studentId;

    private Long classId;

    /** osce_low/assignment_overdue/daily_break/weakness_worsening/behavior_abnormal */
    private String alertType;

    /** 1低 2中 3高 */
    private Integer riskLevel;

    /** 触发规则明细 JSON（连续次数/数值等） */
    private String ruleDetailJson;

    /** 0未处理 1已查看 2已干预 */
    private Integer status;

    /** AI 干预建议 JSON（缓存） */
    private String interventionJson;

    private LocalDateTime resolvedAt;
}
