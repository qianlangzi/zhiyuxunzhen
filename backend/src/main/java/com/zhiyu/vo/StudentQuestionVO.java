package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 学生练习题目（不含答案，交卷后由后端判分）
 */
@Data
@Builder
public class StudentQuestionVO {
    private Long id;
    /** single_choice / multiple_choice / judgment / fill_blank */
    private String questionType;
    private String title;
    /** 选项 JSON（[{"key":"A","text":"..."}]，判断题/填空为空数组） */
    private String optionsJson;
    private Integer difficulty;
    private String knowledgeTag;
}
