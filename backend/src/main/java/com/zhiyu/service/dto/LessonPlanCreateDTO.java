package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 创建/更新备课包请求（助教：智能备课）
 */
@Data
public class LessonPlanCreateDTO {

    @NotBlank(message = "备课标题不能为空")
    @Size(max = 200, message = "备课标题不能超过200字")
    private String title;

    private String department;

    private String targetGrade;

    /** 教学目标（可 AI 生成） */
    private String objectives;

    /** 教学重难点 */
    private String keyPoints;

    /** 关联 SP 病例 ID（自建或引用后） */
    private Long caseId;

    /** 病例来源：0无 1自建 2引用病例广场 */
    private Integer caseSource;

    /** 教案内容 JSON（编辑保存时回写 ai_design_json） */
    private String aiDesign;

    /** 学情目标班级 ID（对话引导时选定） */
    private Long targetClassId;

    /** 选用教材 ID */
    private Long textbookId;

    /** 是否置顶（1=置顶 0=否），空表示不修改 */
    private Integer isTop;

    /** 自定义优先级（0 默认，数值越大越靠前），空表示不修改 */
    private Integer priority;
}
