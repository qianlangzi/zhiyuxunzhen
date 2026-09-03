package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.TextbookIngestReconciliationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 教材入库自动对账实现（定时任务）
 *
 * <h3>扫描条件</h3>
 * ingest_status = 1（处理中）且 last_ingest_at 早于当前时间超过 30 分钟。
 *
 * <h3>多实例防重复</h3>
 * 采用数据库条件更新 / CAS：触发前先执行一次原子 UPDATE，WHERE 携带
 * {@code ingest_status=1 AND (last_ingest_at IS NULL OR last_ingest_at <= cutoff) AND
 * ingest_auto_retry_count = 旧值}，并把 last_ingest_at 推到当前时间、递增自动重试计数。
 * 只更新命中 0 行的任务会被直接跳过——并发扫描（多实例/同时运行）中只有一个 claimant 能
 * 把 last_ingest_at 推到当前时间，因此不会对同一教材重复触发。不依赖 Java synchronized。
 *
 * <h3>失败保真</h3>
 * AI 调用失败时把可解释原因写入 ingest_error 并写审计日志，保持在「处理中」状态等待下一轮，
 * 绝不把失败任务伪装成成功。
 *
 * <h3>旧任务迟到回调</h3>
 * 每次自动重触发生成新的 ingestionId 写入 textbook.ingestion_id，
 * InternalCallbackServiceImpl 据此丢弃携带旧 ingestionId 的迟到回调，防止旧任务覆盖新任务状态。
 *
 * <h3>容错</h3>
 * 单本教材处理抛异常仅记录告警并继续处理下一本，不阻断全部对账。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TextbookIngestReconciliationServiceImpl implements TextbookIngestReconciliationService {

    private final TextbookMapper textbookMapper;
    private final AiPlatformClient aiPlatformClient;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    /** 最大自动重试次数，达到后不再自动触发（需管理员手动介入或回调成功） */
    @Value("${zhiyu.textbook.ingest-reconcile.max-auto-retry:3}")
    private int maxAutoRetry;

    /** 「处理中」超过该时长即视为任务丢失，允许自动重触发 */
    @Value("${zhiyu.textbook.ingest-reconcile.stale-after-minutes:30}")
    private long staleAfterMinutes;

    @Override
    @Scheduled(cron = "${zhiyu.textbook.ingest-reconcile.cron:0 */10 * * * ?}")
    public int reconcile() {
        LocalDateTime cutoff = LocalDateTime.now().minusMinutes(staleAfterMinutes);
        log.info("教材入库对账扫描开始: cutoff={} maxAutoRetry={}", cutoff, maxAutoRetry);

        List<Textbook> candidates = textbookMapper.selectList(
                new LambdaQueryWrapper<Textbook>()
                        .eq(Textbook::getIngestStatus, 1)
                        .and(w -> w.isNull(Textbook::getLastIngestAt)
                                .or().lt(Textbook::getLastIngestAt, cutoff))
                        .and(w -> w.isNull(Textbook::getIngestAutoRetryCount)
                                .or().lt(Textbook::getIngestAutoRetryCount, maxAutoRetry)));

        int triggered = 0;
        for (Textbook tb : candidates) {
            try {
                if (reconcileOne(tb, cutoff)) {
                    triggered++;
                }
            } catch (Exception e) {
                // 单本教材处理异常不阻断其他教材的对账
                log.warn("教材入库对账单本处理异常，跳过继续: textbookId={} error={}",
                        tb.getId(), e.getMessage(), e);
            }
        }
        log.info("教材入库对账扫描完成: candidates={} autoRetriggered={}", candidates.size(), triggered);
        return triggered;
    }

    /**
     * 对单本教材尝试自动重触发。先 CAS 抢占，抢占成功后调用 AI 重触发。
     *
     * @return 是否成功发起一次新的自动重试
     */
    private boolean reconcileOne(Textbook tb, LocalDateTime cutoff) {
        Long id = tb.getId();
        LocalDateTime last = tb.getLastIngestAt();
        // 当前已不再超时（并发扫描已被别人 push last_ingest_at 到当前时间）→ 跳过
        if (last != null && !last.isBefore(cutoff)) {
            return false;
        }
        int oldAutoRetry = tb.getIngestAutoRetryCount() == null ? 0 : tb.getIngestAutoRetryCount();
        // 已达最大自动重试次数 → 不再自动触发
        if (oldAutoRetry >= maxAutoRetry) {
            log.warn("教材入库自动重试次数已达上限，不再自动触发: textbookId={} autoRetry={} max={}",
                    id, oldAutoRetry, maxAutoRetry);
            return false;
        }

        // CAS 抢占：一次性完成「检查超时 + 推后 last_ingest_at + 递增自动重试计数 + 标记自动触发来源」。
        // 多实例并发时 WHERE 中的 (last_ingest_at 超时) 与 ingest_auto_retry_count=旧值 只有一方能命中。
        int rows = textbookMapper.update(null,
                new UpdateWrapper<Textbook>()
                        .eq("id", id)
                        .eq("ingest_status", 1)
                        .eq("ingest_auto_retry_count", oldAutoRetry)
                        .eq("is_deleted", 0)
                        .and(w -> w.isNull("last_ingest_at").or().le("last_ingest_at", cutoff))
                        .set("last_ingest_at", LocalDateTime.now())
                        .set("ingest_auto_retry_count", oldAutoRetry + 1)
                        .set("ingest_trigger_source", Textbook.INGEST_TRIGGER_AUTO));
        if (rows == 0) {
            // 丢失抢占：另一实例/并发扫描已处理或状态已变化，不重复触发
            log.info("教材入库自动对账抢占失败，跳过（避免并发重复触发）: textbookId={}", id);
            return false;
        }
        return triggerWithNewAttempt(tb, oldAutoRetry);
    }

    /**
     * 生成新的 attemptKey 调用 AI 重触发，并落库新 ingestionId、写审计日志。
     */
    private boolean triggerWithNewAttempt(Textbook tb, int oldAutoRetry) {
        Long id = tb.getId();
        if (!StringUtils.hasText(tb.getFileUrl())) {
            recordFailure(tb, oldAutoRetry, null, "教材缺少电子书文件，无法自动重试");
            return false;
        }
        String objectKey = tb.getFileUrl();
        int uploadPrefix = tb.getFileUrl().indexOf("/uploads/");
        if (uploadPrefix >= 0) {
            objectKey = tb.getFileUrl().substring(uploadPrefix + "/uploads/".length());
        }
        if (!StringUtils.hasText(objectKey)) {
            recordFailure(tb, oldAutoRetry, null, "教材文件地址解析失败，无法自动重试");
            return false;
        }

        // 每次自动重触发都生成新的 attemptKey：AI 幂等键含 attemptKey，重试真正创建新任务并重跑
        String attemptKey = UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        String oldIngestionId = tb.getIngestionId();
        Map<String, Object> result;
        try {
            result = aiPlatformClient.ingestKnowledge(
                    id, objectKey, tb.getTitle(), tb.getEdition(), tb.getDepartment(), attemptKey);
        } catch (Exception e) {
            // AI 调用失败：保留可解释失败原因，不伪装成成功
            recordFailure(tb, oldAutoRetry, oldIngestionId,
                    "AI 入库服务调用异常，自动重试降级: " + e.getMessage());
            return false;
        }
        if (result == null || result.get("ingestionId") == null) {
            recordFailure(tb, oldAutoRetry, oldIngestionId, "AI 入库服务不可用，自动重试触发失败");
            return false;
        }

        String newIngestionId = String.valueOf(result.get("ingestionId"));
        // 落库新 ingestionId（ingest_status 保持 1，last_ingest_at / 自动重试计数已在抢占时更新）
        textbookMapper.update(null, new UpdateWrapper<Textbook>()
                .eq("id", id)
                .set("ingestion_id", newIngestionId)
                .set("ingest_error", null));

        recordAudit(tb.getId(), oldIngestionId, newIngestionId,
                oldAutoRetry, oldAutoRetry + 1, "IN_PROGRESS_STALE: 处理中超过 " + staleAfterMinutes + " 分钟未收到回调，自动重触发");
        log.info("教材入库自动对账重触发成功: textbookId={} oldIngestionId={} newIngestionId={} autoRetry={}->{}",
                id, oldIngestionId, newIngestionId, oldAutoRetry, oldAutoRetry + 1);
        return true;
    }

    /** 记录自动重试失败：写 ingest_error 并落审计日志（保持处理中状态，不伪装成功） */
    private void recordFailure(Textbook tb, int oldAutoRetry, String oldIngestionId, String reason) {
        try {
            textbookMapper.update(null, new UpdateWrapper<Textbook>()
                    .eq("id", tb.getId())
                    .set("ingest_error", reason.length() > 500 ? reason.substring(0, 500) : reason));
        } catch (Exception e) {
            log.error("教材自动对账写入失败原因异常: textbookId={} error={}", tb.getId(), e.getMessage());
        }
        recordAudit(tb.getId(), oldIngestionId, null, oldAutoRetry, oldAutoRetry + 1, reason);
        log.warn("教材入库自动对账重触发失败: textbookId={} reason={}", tb.getId(), reason);
    }

    /** 审计日志：textbookId + 原/新 ingestionId + 原/新自动重试次数 + 触发原因 */
    private void recordAudit(Long textbookId, String oldIngestionId, String newIngestionId,
                             int oldRetry, int newRetry, String reason) {
        Map<String, Object> after = new HashMap<>();
        after.put("textbookId", textbookId);
        after.put("oldIngestionId", oldIngestionId);
        after.put("newIngestionId", newIngestionId);
        after.put("oldAutoRetryCount", oldRetry);
        after.put("newAutoRetryCount", newRetry);
        after.put("reason", reason);
        String json;
        try {
            json = objectMapper.writeValueAsString(after);
        } catch (Exception e) {
            log.error("审计 JSON 序列化失败: textbookId={}", textbookId, e);
            json = after.toString();
        }
        auditLogService.record("textbook_ingest_auto_trigger", "textbook", textbookId, null, json);
    }
}