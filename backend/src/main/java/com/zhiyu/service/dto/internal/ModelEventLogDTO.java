package com.zhiyu.service.dto.internal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 模型异常和降级事件回调（PRD 9.4）
 * FastAPI 上报模型调用异常、降级触发等事件
 */
@Data
public class ModelEventLogDTO {

    /** 事件类型：model_error / degradation / timeout 等。最长 88 字符（action 列 VARCHAR(100) - 前缀 "model_event_" 12 字符） */
    @NotBlank
    @Size(max = 88)
    private String eventType;

    private String modelName;

    /** AI 能力/来源：LLM / VISION / EMBEDDING / EMBEDDING_MULTI / fallback */
    private String capability;

    private String errorMessage;

    /** 详细信息 JSON */
    private String detailJson;

    /** 链路追踪 ID */
    private String traceId;

    /** 是否恢复事件：true 表示模型恢复正常 */
    private Boolean recovered;
}
