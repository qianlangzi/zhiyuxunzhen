package com.zhiyu.service.dto.internal;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 教材向量化入库完成回调（AI 中台 → 业务中台）
 * status: 2 成功 / 3 失败
 */
@Data
public class KnowledgeCallbackDTO {

    @NotNull(message = "textbookId 不能为空")
    private Long textbookId;

    /** 2 已入库 3 失败 */
    @NotNull(message = "status 不能为空")
    @Min(2)
    @Max(3)
    private Integer status;

    /** 失败时的错误信息（入库成功时为空） */
    private String error;

    /**
     * AI 中台任务 ID（可选）。携带时用于乱序防护：
     * 若与 textbook 当前记录的 ingestion_id 不一致，说明是旧任务的迟到回调，直接丢弃。
     */
    private String ingestionId;
}