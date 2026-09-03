package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.Map;

/**
 * 学生提交练习任务项答案请求（组合任务包）
 */
@Data
public class PracticeSubmitDTO {

    /** questionId -> 学生答案（多选用逗号分隔，如 "A,B"） */
    @NotNull(message = "答案不能为空")
    private Map<Long, String> answers;
}
