package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

/**
 * 作业表（PRD 8.3）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("assignment")
public class Assignment extends BaseEntity {

    private Long teacherId;

    private Long caseId;

    private String title;

    private String description;

    private Boolean requireMedicalRecord;

    /** 格式盾牌规则 JSON */
    private String formatRuleJson;

    /** 防作弊变量配置 JSON */
    private String antiCheatVariables;

    private LocalDateTime deadline;

    private Boolean allowLateSubmit;

    /** 0草稿 1进行中 2已截止 */

    @TableField("`status`")
    private Integer status;

    @TableLogic
    @TableField(value = "is_deleted")
    private Integer isDeleted;
}
