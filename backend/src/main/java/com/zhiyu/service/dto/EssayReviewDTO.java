package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * 主观题（简答/论述）AI 批阅请求（教师端）
 * 按教师自定义评分要点批阅，返回维度评分与改进建议。
 */
@Data
public class EssayReviewDTO {

    /** 题目内容 */
    @NotBlank(message = "题目不能为空")
    @Size(max = 2000, message = "题目过长")
    private String question;

    /** 教师自定义评分要点（可为空，AI 按通用医学要点批阅） */
    @Size(max = 4000, message = "评分要点过长")
    private String scoringPoints;

    /** 学生作答 */
    @NotBlank(message = "学生作答不能为空")
    @Size(max = 8000, message = "学生作答过长")
    private String studentAnswer;

    /** 可选病例上下文（如批阅对象为大病历场景） */
    @Size(max = 4000, message = "病例上下文过长")
    private String caseContext;

    /** 可选教材引用（AI 中台可据此检索/核对） */
    private List<Map<String, Object>> textbookRefs;

    // ---- 作业任务关联（教师复核闭环：AI 结果需落库并更新任务项状态）----

    /** 作业实例 ID（存量作业批阅定位用） */
    private Long instanceId;

    /** 作业实例 ID 别名（TeacherReviewServiceImpl 输出回填用） */
    private Long assignmentId;

    /** 组合包:任务项进度 ID（主观题所在任务项的进度，批阅定位与状态更新用） */
    private Long itemProgressId;

    /** 主观题 ID（基础题库题目） */
    private Long questionId;

    /** 作答学生 ID（为空时后端按 itemProgressId 推导） */
    private Long studentId;
}
