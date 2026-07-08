package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 教师更新病例请求（PRD 4.1）
 * PUT 全量更新，核心诊断字段已被作业引用时禁止修改
 */
@Data
public class CaseUpdateDTO {

    @NotBlank(message = "病例标题不能为空")
    private String title;

    @NotBlank(message = "所属科室不能为空")
    private String department;

    @NotNull(message = "难度不能为空")
    private Integer difficulty;

    @NotBlank(message = "患者画像不能为空")
    private String patientProfile;

    @NotBlank(message = "隐藏疾病不能为空")
    private String hiddenDisease;

    @NotBlank(message = "标准路径不能为空")
    private String standardPathJson;

    private String presetExams;

    private String knowledgeTags;
}
