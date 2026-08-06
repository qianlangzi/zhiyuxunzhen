package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.List;

/**
 * AI 生成 SP 病例草稿请求
 */
@Data
public class CaseDraftDTO {

    @NotBlank(message = "主诉不能为空")
    private String chiefComplaint;

    @NotBlank(message = "所属科室不能为空")
    private String department;

    /** 1简单 2标准 3困难 */
    private Integer difficulty = 2;

    /** 教学目标/知识点标签 */
    private List<String> teachingGoals;
}