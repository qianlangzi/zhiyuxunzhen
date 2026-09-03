package com.zhiyu.service.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;

import java.util.List;

/**
 * AI 组卷请求（P2-4 学生自测卷）
 * 学生按「薄弱知识点 + 难度偏好 + 题量」生成个性化自测卷。
 */
@Data
public class PaperGenerateRequest {

    /** 目标题量 1~20，默认 10 */
    @Min(value = 1, message = "题量至少为1")
    @Max(value = 20, message = "题量最多为20")
    private Integer count = 10;

    /** 难度偏好 1简单 2标准 3困难，空=不限 */
    @Min(value = 1, message = "难度取值错误")
    @Max(value = 3, message = "难度取值错误")
    private Integer difficulty;

    /** 指定薄弱知识点（可选；不传则取系统统计的薄弱点） */
    private List<String> focusTags;
}
