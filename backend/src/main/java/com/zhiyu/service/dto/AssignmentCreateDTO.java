package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 教师创建作业请求（组合任务包）
 * 作业 = 标题/描述/截止/班级 + 多个任务项(items)。
 * 任务项类型: CASE(病例问诊) / PRACTICE(基础练习) / READING(阅读任务)
 */
@Data
public class AssignmentCreateDTO {

    @NotBlank(message = "作业标题不能为空")
    private String title;

    private String description;

    @NotNull(message = "截止时间不能为空")
    private LocalDateTime deadline;

    /** 是否允许迟交，默认 false */
    private Boolean allowLateSubmit;

    @NotEmpty(message = "至少选择一个班级")
    private List<Long> classIds;

    @NotEmpty(message = "至少添加一个任务项")
    private List<Item> items;

    @Data
    public static class Item {

        @NotBlank(message = "任务项类型不能为空")
        private String itemType;

        /** 任务项标题（可空，后端按类型自动生成默认标题） */
        private String title;

        /** CASE:病例ID */
        private Long caseId;

        /** CASE:防作弊变量模板 JSON（可选） */
        private String antiCheatVariables;

        /** CASE:是否要求提交大病历，默认 true */
        private Boolean requireMedicalRecord;

        /** CASE:格式盾牌规则 JSON（可选） */
        private String formatRuleJson;

        /** PRACTICE:题目ID列表 */
        private List<Long> questionIds;

        /** READING:教材ID */
        private Long textbookId;

        /** READING:阅读范围（章节/页码范围） */
        private String readingScope;
    }
}
