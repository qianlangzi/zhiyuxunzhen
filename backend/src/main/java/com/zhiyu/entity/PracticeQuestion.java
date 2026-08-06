package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 基础题题库表
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("practice_question")
public class PracticeQuestion extends BaseEntity {

    /** single_choice / judgment */
    private String questionType;

    private String knowledgeTag;

    private String title;

    /** JSON 选项数组 */
    private String optionsJson;

    /** 正确选项 index 或答案 */
    private String answer;

    private String explanation;

    /** 1简单 2标准 3困难 */
    private Integer difficulty;

    /** 关联教材 */
    private Long sourceTextbookId;

    /** 0下架 1上架 */
    private Integer status;
}