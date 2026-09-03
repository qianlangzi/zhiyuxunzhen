package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * AI 模型运行事件视图对象（管理端「最近模型事件」）
 * 只暴露业务可读字段，绝不包含 API Key / Authorization 等敏感信息。
 */
@Data
@Builder
public class ModelEventLogVO {

    private Long id;

    /** 事件类型：model_error / degradation / timeout / recovered / info */
    private String eventType;

    /** 模型名称（脱敏） */
    private String modelName;

    /** AI 能力/来源：LLM / VISION / EMBEDDING / EMBEDDING_MULTI / fallback */
    private String capability;

    /** 业务可读的原因文案 */
    private String errorMessage;

    /** 结构化补充信息 JSON 字符串 */
    private String detailJson;

    /** 链路追踪 ID */
    private String traceId;

    /** 是否恢复事件 */
    private Boolean recovered;

    private LocalDateTime createdAt;
}