package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * 会话 OSCE 评估结果 VO
 *
 * 字段对齐 ai/app/agents/evaluator_agent.py 的输出 schema：
 * scores/comments 4 维（history / logic / communication / humanity）
 */
@Data
@Builder
public class SessionEvaluationVO {
    private Long sessionId;
    private Long caseId;
    /** 4 维评分：{history, logic, communication, humanity}，每维 0-25 */
    private Map<String, Object> scores;
    /** 4 维评语 */
    private Map<String, Object> comments;
    private List<String> strengths;
    private List<String> improvements;
    /** AI 总结评语 */
    private String finalReport;
    /** 错题列表（结构：type/knowledge_tag/student_answer/standard_answer/evidence） */
    private List<Map<String, Object>> mistakes;
    /** 总分 0-100 */
    private Double totalScore;
    /** 会话状态：0 进行中 / 1 已完成 / 2 异常中断 */
    private Integer status;
}
