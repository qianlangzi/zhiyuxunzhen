package com.zhiyu.service.dto.internal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Token 用量上报（V39）
 * AI 中台 llm_client 在 chat()/stream() 出口统计后异步上报，
 * 是管理端「Token 管理」的唯一数据来源。
 */
@Data
public class TokenUsageReportDTO {

    /** 链路追踪 ID */
    @Size(max = 64)
    private String traceId;

    /** 调用场景：chat / review / lesson / case / companion / mistake / paper / evaluate */
    @Size(max = 64)
    private String scene;

    /** AI 能力：LLM / VISION / EMBEDDING / EMBEDDING_MULTI */
    @Size(max = 32)
    private String capability;

    /** 模型标识（脱敏，不含密钥） */
    @NotBlank
    @Size(max = 128)
    private String model;

    private Integer promptTokens;

    private Integer completionTokens;

    private Integer totalTokens;

    private Integer latencyMs;

    private Long studentId;

    private Long sessionId;

    /** 是否成功 */
    private Boolean success;

    /** 是否流式调用 */
    private Boolean isStream;
}
