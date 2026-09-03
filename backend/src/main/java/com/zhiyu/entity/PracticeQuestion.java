package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 基础题题库表
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("practice_question")
public class PracticeQuestion extends BaseEntity {

    /** 统一题号（如 ST000001） */
    private String questionNo;

    /** single_choice / judgment */
    private String questionType;

    /** 所属科室/模块（如：心血管内科、呼吸内科） */
    private String department;

    private String knowledgeTag;

    private String title;

    /** JSON 选项数组 */
    private String optionsJson;

    /** 正确选项 index 或答案 */
    private String answer;

    private String explanation;

    /** 1简单 2标准 3困难 */
    private Integer difficulty;

    /** 关联教材 */
    private Long sourceTextbookId;

    /** 0下架 1上架 */
    private Integer status;

    /** 题库审核状态：0未提交 1待审核 2通过 3驳回 */
    private Integer adminAuditStatus;

    /** 提交人（教师）ID */
    private Long submitterId;

    /** 管理端驳回复核意见 */
    private String rejectReason;
}