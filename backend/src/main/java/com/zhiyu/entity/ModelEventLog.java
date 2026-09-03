package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * AI 模型运行事件（V24）
 * 与 audit_log 的 model_event_* 审计记录互补：这里以结构化列持久化
 * trace_id / detail_json / capability / recovered，供管理端「最近模型事件」展示。
 * 只增不删不改。
 */
@Data
@TableName("model_event_log")
public class ModelEventLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 事件类型：model_error / degradation / timeout / recovered / info */
    private String eventType;

    /** 模型名称（脱敏，不含密钥） */
    private String modelName;

    /** AI 能力/来源：LLM / VISION / EMBEDDING / EMBEDDING_MULTI / fallback */
    private String capability;

    /** 业务可读的原因文案（杜绝异常堆栈） */
    private String errorMessage;

    /** 结构化补充信息（不含密钥 / Authorization） */
    private String detailJson;

    /** 本次请求链路追踪 ID */
    private String traceId;

    /** 是否恢复事件：true 恢复，false 异常/降级 */
    private Boolean recovered;

    private LocalDateTime createdAt;
}