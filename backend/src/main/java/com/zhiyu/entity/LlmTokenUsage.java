package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 大模型 Token 用量流水（V39）
 * 由 AI 中台在 llm_client 出口统计后经内部回调上报，只增不改。
 */
@Data
@TableName("llm_token_usage")
public class LlmTokenUsage {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 链路追踪 ID，与 AI 中台日志对账用 */
    private String traceId;

    /** 调用场景：chat/review/lesson/case/companion/mistake/paper/evaluate 等 */
    private String scene;

    /** AI 能力：LLM / VISION / EMBEDDING / EMBEDDING_MULTI */
    private String capability;

    /** 模型标识（脱敏，不含密钥） */
    private String model;

    private Integer promptTokens;

    private Integer completionTokens;

    private Integer totalTokens;

    private Integer latencyMs;

    private Long studentId;

    private Long sessionId;

    /** 是否成功：true 成功，false 失败（失败调用也可能产生费用） */
    private Boolean success;

    /** 是否流式调用 */
    private Boolean isStream;

    private LocalDateTime createdAt;
}
