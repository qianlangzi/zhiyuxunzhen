package com.zhiyu.service.dto.internal;

import lombok.Data;

/**
 * 模型异常和降级事件回调（PRD 9.4）
 * FastAPI 上报模型调用异常、降级触发等事件
 */
@Data
public class ModelEventLogDTO {

    /** 事件类型：model_error / degradation / timeout 等 */
    private String eventType;

    private String modelName;

    private String errorMessage;

    /** 详细信息 JSON */
    private String detailJson;
}
