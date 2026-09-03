package com.zhiyu.service;

/**
 * 教材入库自动对账服务
 *
 * 定时扫描「处理中但长时间未收到回调」的教材（任务可能因 AI worker 崩溃/丢失而卡死），
 * 自动生成新的 ingestionId / attemptKey 重新触发入库，而不是让状态永久卡在「处理中」。
 *
 * 与管理员手动重试（AdminService#triggerTextbookIngest）区分：
 *  - 触发来源标识不同（自动对账=2，管理员手动=1，见 Textbook.INGEST_TRIGGER_*）；
 *  - 自动重试计入独立的 ingest_auto_retry_count，受最大自动重试次数约束，不会无限重试；
 *  - 管理端手动重试会重置自动重试计数，给新任务一个完整可用的自动重试预算。
 */
public interface TextbookIngestReconciliationService {

    /**
     * 执行一轮教材入库对账。
     * 逐本处理，单本异常不影响其他教材；返回本轮成功自动重试的教材数量。
     */
    int reconcile();
}