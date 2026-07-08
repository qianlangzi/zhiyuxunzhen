package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 教师创建作业请求（PRD 4.3）
 */
@Data
public class AssignmentCreateDTO {

    @NotNull(message = "病例ID不能为空")
    private Long caseId;

    @NotBlank(message = "作业标题不能为空")
    private String title;

    private String description;

    /** 是否要求提交大病历，默认 true */
    private Boolean requireMedicalRecord;

    /** 格式盾牌规则 JSON（可选） */
    private String formatRuleJson;

    /** 防作弊变量配置 JSON（可选） */
    private String antiCheatVariables;

    @NotNull(message = "截止时间不能为空")
    private LocalDateTime deadline;

    /** 是否允许迟交，默认 false */
    private Boolean allowLateSubmit;

    @NotEmpty(message = "至少选择一个班级")
    private List<Long> classIds;
}
