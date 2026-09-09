package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 作业任务项表（组合任务包）
 * 一个作业(assignment)包含多个任务项:病例问诊(CASE) / 基础练习(PRACTICE) / 阅读任务(READING)
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("assignment_item")
public class AssignmentItem extends BaseEntity {

    private Long assignmentId;

    /** CASE / PRACTICE / READING */
    private String itemType;

    private String title;

    private Integer sortOrder;

    /** CASE:病例ID */
    private Long caseId;

    /** CASE:防作弊变量模板 JSON */
    private String antiCheatVariables;

    /** CASE:是否要求提交大病历 */
    private Boolean requireMedicalRecord;

    /** CASE:格式盾牌规则 JSON */
    private String formatRuleJson;

    /** PRACTICE:题目ID列表 JSON [1,2,3] */
    private String questionIds;

    /** READING:教材ID */
    private Long textbookId;

    /** READING:阅读范围(章节/页码范围) */
    private String readingScope;

    /** MATERIAL:备课资料ID(lesson_material.id) */
    private Long lessonMaterialId;

    @TableLogic
    private Integer isDeleted;
}
