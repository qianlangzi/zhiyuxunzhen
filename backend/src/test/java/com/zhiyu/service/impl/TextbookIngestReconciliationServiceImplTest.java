package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.AuditLogService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 教材入库自动对账单测
 *
 * 覆盖（对应准入要求）：
 * 1. 超时任务会被重新触发
 * 2. 未超时任务不会触发
 * 3. 达到最大自动重试次数后不再触发
 * 4. 两次并发扫描不会重复触发（CAS 抢占失败即跳过）
 * 5. 自动重触发写入新 ingestionId → 旧 ingestionId 迟到回调无法覆盖新任务（配合
 *    InternalCallbackKnowledgeCallbackTest 的乱序丢弃逻辑闭环）
 */
@ExtendWith(MockitoExtension.class)
class TextbookIngestReconciliationServiceImplTest {

    @Mock
    private TextbookMapper textbookMapper;
    @Mock
    private AiPlatformClient aiPlatformClient;
    @Mock
    private AuditLogService auditLogService;

    private final int maxAutoRetry = 3;
    private final long staleAfterMinutes = 30;

    /** 以真实对象构建服务并注入 @Value 配置字段 */
    private TextbookIngestReconciliationServiceImpl newService() {
        TextbookIngestReconciliationServiceImpl s =
                new TextbookIngestReconciliationServiceImpl(textbookMapper, aiPlatformClient, auditLogService,
                        new ObjectMapper());
        ReflectionTestUtils.setField(s, "maxAutoRetry", maxAutoRetry);
        ReflectionTestUtils.setField(s, "staleAfterMinutes", staleAfterMinutes);
        return s;
    }

    /** 构造一个「处理中」且已超时的教材 */
    private Textbook staleTextbook(Long id) {
        Textbook tb = new Textbook();
        tb.setId(id);
        tb.setIngestStatus(1);
        tb.setFileUrl("/uploads/ebooks/abc.pdf");
        tb.setTitle("《诊断学》");
        tb.setEdition("第9版");
        tb.setDepartment("内科");
        tb.setIngestionId("task-old-1");
        tb.setIngestAutoRetryCount(0);
        tb.setLastIngestAt(LocalDateTime.now().minusHours(1)); // 超时
        return tb;
    }

    /**
     * 【并发防重】mock 对 CAS「抢占」update 的返回值（占位：不含 ingestion_id 的 set 即抢占）：
     * 默认抢占成功(1)；测试可通过 claimRows 控制。
     */
    private void stubClaimAndIngestionUpdate(int claimRows) {
        when(textbookMapper.update(eq(null), any(Wrapper.class))).thenAnswer(inv -> {
            com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<Textbook> uw = inv.getArgument(1);
            String sqlSet = uw.getSqlSet();
            if (sqlSet != null && sqlSet.contains("ingestion_id")) {
                return 1; // 写新 ingestionId 的更新
            }
            return claimRows; // 抢占 CAS 的行数
        });
    }

    @Test
    @DisplayName("超时任务会被重新触发：CAS 抢占成功 → 生成新 attemptKey 调 AI → 写新 ingestionId + 审计日志")
    void staleTaskIsRetriggered() {
        Textbook tb = staleTextbook(7L);
        when(textbookMapper.selectList(any(Wrapper.class))).thenReturn(List.of(tb));
        stubClaimAndIngestionUpdate(1);

        Map<String, Object> aiResp = new HashMap<>();
        aiResp.put("ingestionId", "task-new-2");
        when(aiPlatformClient.ingestKnowledge(eq(7L), eq("ebooks/abc.pdf"), any(), any(), any(), any()))
                .thenReturn(aiResp);

        TextbookIngestReconciliationServiceImpl service = newService();
        int n = service.reconcile();

        assertThat(n).isEqualTo(1);
        // 触发新任务，且 attemptKey 变化（每次自动重试生成新幂等键）
        verify(aiPlatformClient).ingestKnowledge(eq(7L), eq("ebooks/abc.pdf"), any(), any(), any(), any());
        // 写了新的 ingestionId（旧 task-old-1 迟到回调因 ingestionId 不匹配被 InternalCallback 丢弃）
        ArgumentCaptor<com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<Textbook>> uwCaptor =
                ArgumentCaptor.forClass(com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper.class);
        verify(textbookMapper, org.mockito.Mockito.atLeastOnce())
                .update(eq(null), uwCaptor.capture());
        boolean wroteNewId = uwCaptor.getAllValues().stream()
                .anyMatch(u -> u.getParamNameValuePairs() != null
                        && u.getParamNameValuePairs().containsValue("task-new-2"));
        assertThat(wroteNewId).as("应写入新的 ingestionId").isTrue();
        // 审计日志含 textbookId / 新旧 ingestionId / 新旧重试次数 / 触发原因
        ArgumentCaptor<String> actionCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Long> idCaptor = ArgumentCaptor.forClass(Long.class);
        ArgumentCaptor<String> jsonCaptor = ArgumentCaptor.forClass(String.class);
        verify(auditLogService).record(actionCaptor.capture(), eq("textbook"), idCaptor.capture(),
                eq(null), jsonCaptor.capture());
        assertThat(actionCaptor.getValue()).isEqualTo("textbook_ingest_auto_trigger");
        assertThat(idCaptor.getValue()).isEqualTo(7L);
        assertThat(jsonCaptor.getValue())
                .contains("\"textbookId\":7")
                .contains("task-old-1")
                .contains("task-new-2")
                .contains("\"oldAutoRetryCount\":0")
                .contains("\"newAutoRetryCount\":1");
    }

    @Test
    @DisplayName("未超时任务不会触发：last_ingest_at 距今不足阈值 → 不调 AI")
    void nonStaleTaskIsNotTriggered() {
        Textbook tb = staleTextbook(8L);
        tb.setLastIngestAt(LocalDateTime.now().minusSeconds(60)); // 未超时
        when(textbookMapper.selectList(any(Wrapper.class))).thenReturn(List.of(tb));

        int n = newService().reconcile();

        assertThat(n).isZero();
        verify(aiPlatformClient, never())
                .ingestKnowledge(any(), any(), any(), any(), any(), any());
    }

    @Test
    @DisplayName("达到最大自动重试次数后不再触发")
    void maxAutoRetryNotExceeded() {
        Textbook tb = staleTextbook(9L);
        tb.setIngestAutoRetryCount(maxAutoRetry); // 已达上限
        when(textbookMapper.selectList(any(Wrapper.class))).thenReturn(List.of(tb));
        // 不应走到抢占更新，update 不会带 ingestion_id

        int n = newService().reconcile();

        assertThat(n).isZero();
        verify(aiPlatformClient, never())
                .ingestKnowledge(any(), any(), any(), any(), any(), any());
        verify(auditLogService, never()).record(any(), any(), any(), any(), any());
    }

    @Test
    @DisplayName("两次并发扫描不重复触发：CAS 抢占失败（rows=0）→ 跳过，不调 AI")
    void concurrentScanDoesNotDoubleTrigger() {
        Textbook tb = staleTextbook(10L);
        when(textbookMapper.selectList(any(Wrapper.class))).thenReturn(List.of(tb));
        stubClaimAndIngestionUpdate(0); // 另一实例已抢占

        int n = newService().reconcile();

        assertThat(n).isZero();
        verify(aiPlatformClient, never())
                .ingestKnowledge(any(), any(), any(), any(), any(), any());
        verify(auditLogService, never()).record(any(), any(), any(), any(), any());
    }

    @Test
    @DisplayName("AI 调用失败时保留可解释失败原因并写审计日志（不伪装成功）")
    void aiFailureRetainsReasonAndWritesAudit() {
        Textbook tb = staleTextbook(11L);
        when(textbookMapper.selectList(any(Wrapper.class))).thenReturn(List.of(tb));
        // 抢占成功，但 AI 返回不可用（无 ingestionId）→ 保留失败原因
        stubClaimAndIngestionUpdate(1);
        when(aiPlatformClient.ingestKnowledge(eq(11L), eq("ebooks/abc.pdf"), any(), any(), any(), any()))
                .thenReturn(null);

        int n = newService().reconcile();

        assertThat(n).isZero();
        // 写失败原因 update（含 ingest_error）
        ArgumentCaptor<com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<Textbook>> uwCaptor =
                ArgumentCaptor.forClass(com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper.class);
        verify(textbookMapper, org.mockito.Mockito.atLeastOnce())
                .update(eq(null), uwCaptor.capture());
        boolean wroteError = uwCaptor.getAllValues().stream()
                .anyMatch(u -> u.getSqlSet() != null && u.getSqlSet().contains("ingest_error"));
        assertThat(wroteError).as("应记录失败原因，而非伪装成功").isTrue();
        // 审计日志记录失败
        ArgumentCaptor<String> jsonCaptor = ArgumentCaptor.forClass(String.class);
        verify(auditLogService).record(any(), eq("textbook"), eq(11L), eq(null), jsonCaptor.capture());
        assertThat(jsonCaptor.getValue()).contains("AI 入库服务不可用");
    }
}