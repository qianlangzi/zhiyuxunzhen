package com.zhiyu.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.ModelEventLogMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.WeaknessAnalysisService;
import com.zhiyu.service.dto.internal.KnowledgeCallbackDTO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 教材入库回调乱序防护单测
 *
 * 覆盖：
 * 1. 回调携带的 ingestionId 与 textbook 记录的最近任务不一致 → 丢弃（旧任务迟到回调不污染新任务状态）
 * 2. ingestionId 一致 → 正常更新状态，失败原因截断 500
 * 3. 旧版不带 ingestionId 的回调（兼容存量）→ 接受
 */
@ExtendWith(MockitoExtension.class)
class InternalCallbackKnowledgeCallbackTest {

    @Mock
    private TextbookMapper textbookMapper;
    @Mock
    private AuditLogService auditLogService;
    @Mock
    private WeaknessAnalysisService weaknessAnalysisService;
    @Mock
    private ChatSessionMapper chatSessionMapper;
    @Mock
    private MedicalRecordReviewMapper medicalRecordReviewMapper;
    @Mock
    private AssignmentInstanceMapper assignmentInstanceMapper;
    @Mock
    private AssignmentItemProgressMapper assignmentItemProgressMapper;
    @Mock
    private StudentMistakesMapper studentMistakesMapper;
    @Mock
    private StudentWeaknessMapper studentWeaknessMapper;
    @Mock
    private ModelEventLogMapper modelEventLogMapper;

    private InternalCallbackServiceImpl newService() {
        return new InternalCallbackServiceImpl(
                chatSessionMapper, medicalRecordReviewMapper, assignmentInstanceMapper,
                assignmentItemProgressMapper, studentMistakesMapper, studentWeaknessMapper,
                textbookMapper, auditLogService, new ObjectMapper(), weaknessAnalysisService,
                modelEventLogMapper);
    }

    @Test
    @DisplayName("旧任务迟到回调（ingestionId 不匹配）被丢弃，不覆盖新任务状态")
    void staleCallbackWithMismatchedIngestionIdIsDropped() {
        Textbook tb = new Textbook();
        tb.setId(7L);
        tb.setIngestStatus(1);          // 新任务处理中
        tb.setIngestionId("task-new");  // 最近一次任务是 task-new
        when(textbookMapper.selectById(7L)).thenReturn(tb);

        KnowledgeCallbackDTO dto = new KnowledgeCallbackDTO();
        dto.setTextbookId(7L);
        dto.setStatus(3);               // 旧任务失败
        dto.setError("旧任务 Milvus 不可用");
        dto.setIngestionId("task-old"); // 迟到的是旧任务

        newService().knowledgeCallback(dto);

        // 关键断言：updateById 从未被调用 → 新任务状态未被旧任务失败回调污染
        verify(textbookMapper, never()).updateById(any(Textbook.class));
        assertThat(tb.getIngestStatus()).isEqualTo(1);
        assertThat(tb.getIngestError()).isNull();
    }

    @Test
    @DisplayName("ingestionId 匹配 → 更新状态并截断失败原因到 500 字符")
    void matchingIngestionIdUpdatesStatusAndTruncatesError() {
        Textbook tb = new Textbook();
        tb.setId(7L);
        tb.setIngestStatus(1);
        tb.setIngestionId("task-new");
        when(textbookMapper.selectById(7L)).thenReturn(tb);

        String longError = "E".repeat(1200);
        KnowledgeCallbackDTO dto = new KnowledgeCallbackDTO();
        dto.setTextbookId(7L);
        dto.setStatus(3);
        dto.setError(longError);
        dto.setIngestionId("task-new");

        newService().knowledgeCallback(dto);

        ArgumentCaptor<Textbook> captor = ArgumentCaptor.forClass(Textbook.class);
        verify(textbookMapper).updateById(captor.capture());
        assertThat(captor.getValue().getIngestStatus()).isEqualTo(3);
        assertThat(captor.getValue().getIngestError()).hasSize(500);
        assertThat(captor.getValue().getIngestionId()).isEqualTo("task-new");
    }

    @Test
    @DisplayName("兼容存量：不带 ingestionId 的回调被接受（无乱序判别依据）")
    void legacyCallbackWithoutIngestionIdIsAccepted() {
        Textbook tb = new Textbook();
        tb.setId(7L);
        tb.setIngestStatus(1);
        when(textbookMapper.selectById(7L)).thenReturn(tb);

        KnowledgeCallbackDTO dto = new KnowledgeCallbackDTO();
        dto.setTextbookId(7L);
        dto.setStatus(2); // 成功
        dto.setIngestionId(null);

        newService().knowledgeCallback(dto);

        ArgumentCaptor<Textbook> captor = ArgumentCaptor.forClass(Textbook.class);
        verify(textbookMapper).updateById(captor.capture());
        assertThat(captor.getValue().getIngestStatus()).isEqualTo(2);
    }
}
