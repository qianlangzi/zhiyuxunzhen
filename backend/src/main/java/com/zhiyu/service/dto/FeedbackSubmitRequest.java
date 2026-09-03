package com.zhiyu.service.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 学生反馈提交请求（P2-3）
 */
@Data
public class FeedbackSubmitRequest {

    /** 功能 / 学习内容 / 使用问题 / 建议 / 其他 */
    @Size(max = 32, message = "分类长度不能超过32")
    private String category;

    /** 满意度 1-5，0=未评分 */
    @Min(value = 0, message = "评分不能小于0")
    @Max(value = 5, message = "评分不能大于5")
    private Integer rating;

    @Size(max = 1000, message = "反馈内容不能超过1000字")
    private String content;
}
