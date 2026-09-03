package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 教师学情诊断报告（P1-1）
 *
 * 教师基于真实聚合统计 + AI 归纳生成并持久化的班级学情报告，
 * 支持历史查看/删除，避免每次进入学情页都重新调用 AI。
 * classId 为空表示「全体学生」粒度。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("learning_diagnosis")
public class LearningDiagnosis extends BaseEntity {

    /** 生成报告的教师 */
    private Long teacherId;

    /** 报告范围：班级 ID；null 表示全体学生 */
    private Long classId;

    /** 范围名称（班级名 / 全体学生） */
    private String className;

    /** 报告标题 */
    private String title;

    /** 报告内容快照 JSON（统计 + AI 归纳） */
    private String summaryJson;

    /** 内容来源：AI / RULE（AI 不可用时降级） */
    private String source;

    /** 状态：SUCCESS / DEGRADED */
    private String status;
}