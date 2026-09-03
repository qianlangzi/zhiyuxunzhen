package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * AI 中台活跃提示词（内部接口 /api/internal/prompt/active 返回）
 * 走内网信任边界（X-Internal-Token 鉴权）。同一 name 至多一个，返回已启用且激活项。
 */
@Data
@Builder
public class ActivePromptVO {
    private Long id;
    /** 提示词逻辑键（如 sp / mentor / evaluator） */
    private String name;
    private String version;
    private String content;
}