package com.zhiyu.service.dto;

import lombok.Data;

/**
 * AI 学伴偏好更新请求（PUT /api/v1/student/preferences）
 * 按需传参：只更新给定字段。
 */
@Data
public class PreferenceUpdateRequest {

    /** 语气档位：warm 温暖鼓励 / strict 严谨专业 / lively 活泼轻松 / concise 简洁高效 */
    private String aiTone;

    /** 记忆开关：是否允许 AI 记录并召回长期记忆 */
    private Boolean aiMemoryEnabled;
}
