package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 教师更新病例请求（PRD 4.1）
 * PUT 全量更新，核心诊断字段已被作业引用时禁止修改
 * 仅标题必填：更新即"存草稿"，发布完整性由 publishToMarket 校验兜底
 */
@Data
public class CaseUpdateDTO {

    @NotBlank(message = "病例标题不能为空")
    private String title;

    /** 所属科室（草稿可空） */
    private String department;

    /** 1简单 2标准 3困难（草稿可空） */
    private Integer difficulty;

    /** 患者画像 JSON 字符串（草稿可空） */
    private String patientProfile;

    /** 隐藏疾病（草稿可空） */
    private String hiddenDisease;

    /** 标准问诊、检查、诊断路径 JSON（草稿可空） */
    private String standardPathJson;

    private String presetExams;

    private String knowledgeTags;

    /** 标准答案 / 诊断要点 */
    private String referenceAnswer;

    /** 评分要点 JSON 数组 */
    private String scoringPointsJson;
}
