package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

/**
 * 学生作业实例表（PRD 8.4）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("assignment_instance")
public class AssignmentInstance extends BaseEntity {

    private Long assignmentId;

    private Long studentId;

    private Long caseId;

    /** 该学生的防作弊变量快照 JSON */
    private String variableSnapshotJson;

    private Long sessionId;

    /** 大病历正文 */
    private String medicalRecordText;

    /** 格式盾牌校验结果 JSON */
    private String formatCheckResult;

    private LocalDateTime submitTime;

    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */

    @TableField("`status`")
    private Integer status;

    @TableLogic
    @TableField(value = "is_deleted")
    private Integer isDeleted;
}
