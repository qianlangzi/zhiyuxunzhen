package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 教师创建病例请求（PRD 4.1）
 */
@Data
public class CaseCreateDTO {

    @NotBlank(message = "病例标题不能为空")
    private String title;

    @NotBlank(message = "所属科室不能为空")
    private String department;

    /** 1简单 2标准 3困难 */
    @NotNull(message = "难度不能为空")
    private Integer difficulty;

    /** 患者画像 JSON 字符串 */
    @NotBlank(message = "患者画像不能为空")
    private String patientProfile;

    @NotBlank(message = "隐藏疾病不能为空")
    private String hiddenDisease;

    /** 标准问诊、检查、诊断路径 JSON */
    @NotBlank(message = "标准路径不能为空")
    private String standardPathJson;

    /** 检查项目、结果、费用、是否关键 JSON（可选） */
    private String presetExams;

    /** 知识点标签 JSON 数组（可选） */
    private String knowledgeTags;
}
