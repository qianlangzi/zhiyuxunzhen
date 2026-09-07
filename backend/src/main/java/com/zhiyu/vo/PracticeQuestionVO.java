package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 基础题 VO
 */
@Data
@Builder
public class PracticeQuestionVO {
    private Long id;
    /** 统一题号（如 ST000001） */
    private String questionNo;
    /** single_choice / judgment */
    private String questionType;
    /** 所属科室/模块 */
    private String department;
    private String knowledgeTag;
    private String title;
    /** 选项列表 */
    private List<String> options;
    /** 正确选项 index 或答案 */
    private String answer;
    private String explanation;
    /** 1简单 2标准 3困难 */
    private Integer difficulty;
    private Long sourceTextbookId;
    private String sourceTextbookTitle;
    /** 当前学生是否已作答（账户级持久化） */
    private Boolean answered;
    /** 当前学生最近一次所选答案 */
    private String myAnswer;
    /** 当前学生最近一次是否答对（null 表示未作答/需自评题型） */
    private Boolean correct;
}