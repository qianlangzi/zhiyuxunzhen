package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

/**
 * 教师提交基础题（进入管理端审核闭环）
 */
@Data
public class TeacherQuestionCreateDTO {

    /** single_choice / multiple_choice / judgment / fill_blank */
    @NotBlank(message = "题型不能为空")
    private String questionType;

    /** 所属科室/模块（如：心血管内科） */
    @NotBlank(message = "科室不能为空")
    private String department;

    @NotBlank(message = "知识点不能为空")
    private String knowledgeTag;

    @NotBlank(message = "题干不能为空")
    private String title;

    /** 选项数组（JSON），单选/多选必填 */
    private List<String> options;

    @NotBlank(message = "标准答案不能为空")
    private String answer;

    @NotBlank(message = "答案解析不能为空")
    private String explanation;

    /** 1简单 2标准 3困难 */
    @NotNull(message = "难度不能为空")
    private Integer difficulty;

    /** 关联教材（可选） */
    private Long sourceTextbookId;
}