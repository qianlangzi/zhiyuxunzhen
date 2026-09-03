package com.zhiyu.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.entity.ModelEventLog;
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
import com.zhiyu.service.dto.internal.ModelEventLogDTO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;

/**
 * 模型事件回调落库单测
 *
 * 覆盖：
 * 1. 结构化字段（eventType/modelName/capability/detailJson/traceId/recovered）真正持久化
 * 2. errorMessage/detailJson 含引号、反斜杠、换行等特殊字符时，审计 JSON 仍合法（不产生非法 JSON）
 * 3. 超长字段按列宽截断
 */
@ExtendWith(MockitoExtension.class)
class InternalCallbackModelEventLogTest {

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
    private TextbookMapper textbookMapper;
    @Mock
    private AuditLogService auditLogService;
    @Mock
    private WeaknessAnalysisService weaknessAnalysisService;
    @Mock
    private ModelEventLogMapper modelEventLogMapper;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private InternalCallbackServiceImpl newService() {
        return new InternalCallbackServiceImpl(
                chatSessionMapper, medicalRecordReviewMapper, assignmentInstanceMapper,
                assignmentItemProgressMapper, studentMistakesMapper, studentWeaknessMapper,
                textbookMapper, auditLogService, objectMapper, weaknessAnalysisService,
                modelEventLogMapper);
    }

    @Test
    @DisplayName("模型事件时间/降级：detailJson、traceId、capability、recovered 均被持久化")
    void modelEventPersistsStructuredFields() {
        ModelEventLogDTO dto = new ModelEventLogDTO();
        dto.setEventType("timeout");
        dto.setModelName("deepseek-chat");
        dto.setCapability("LLM");
        dto.setErrorMessage("模型请求超时");
        dto.setDetailJson("{\"timeoutSeconds\":30}");
        dto.setTraceId("trace-abc-123");
        dto.setRecovered(false);

        newService().logModelEvent(dto);

        ArgumentCaptor<ModelEventLog> captor = ArgumentCaptor.forClass(ModelEventLog.class);
        verify(modelEventLogMapper).insert(captor.capture());
        ModelEventLog saved = captor.getValue();
        assertThat(saved.getEventType()).isEqualTo("timeout");
        assertThat(saved.getModelName()).isEqualTo("deepseek-chat");
        assertThat(saved.getCapability()).isEqualTo("LLM");
        assertThat(saved.getErrorMessage()).isEqualTo("模型请求超时");
        assertThat(saved.getDetailJson()).isEqualTo("{\"timeoutSeconds\":30}");
        assertThat(saved.getTraceId()).isEqualTo("trace-abc-123");
        assertThat(saved.getRecovered()).isFalse();
        assertThat(saved.getCreatedAt()).isNotNull();
    }

    @Test
    @DisplayName("恢复事件：recovered=true 被正确持久化")
    void recoveredEventPersistsFlag() {
        ModelEventLogDTO dto = new ModelEventLogDTO();
        dto.setEventType("recovered");
        dto.setModelName("deepseek-chat");
        dto.setCapability("LLM");
        dto.setErrorMessage("模型恢复正常");
        dto.setRecovered(true);

        newService().logModelEvent(dto);

        ArgumentCaptor<ModelEventLog> captor = ArgumentCaptor.forClass(ModelEventLog.class);
        verify(modelEventLogMapper).insert(captor.capture());
        assertThat(captor.getValue().getRecovered()).isTrue();
    }

    @Test
    @DisplayName("特殊字符：引号/反斜杠/换行不产生非法审计 JSON，且审计动作带 model_event_ 前缀")
    void specialCharactersDoNotProduceInvalidJson() throws Exception {
        String nasty = "供应商返回:\"额度超限\" / C:\\tmp\\x\r\n第二行 \"引号\"";
        ModelEventLogDTO dto = new ModelEventLogDTO();
        dto.setEventType("model_error");
        dto.setModelName("deepseek-chat");
        dto.setCapability("LLM");
        dto.setErrorMessage(nasty);

        newService().logModelEvent(dto);

        ArgumentCaptor<String> action = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> targetType = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> after = ArgumentCaptor.forClass(String.class);
        verify(auditLogService).record(action.capture(), targetType.capture(),
                org.mockito.ArgumentMatchers.isNull(),
                org.mockito.ArgumentMatchers.isNull(), after.capture());

        assertThat(action.getValue()).isEqualTo("model_event_model_error");
        assertThat(targetType.getValue()).isEqualTo("model");
        // 审计 afterJson 必须是合法 JSON，且能还原原始文案
        @SuppressWarnings("unchecked")
        Map<String, Object> parsed = objectMapper.readValue(after.getValue(), Map.class);
        assertThat(parsed.get("errorMessage")).isEqualTo(nasty);
        assertThat(parsed.get("recovered")).isEqualTo(Boolean.FALSE);
    }

    @Test
    @DisplayName("超长字段按数据库列宽截断，避免写入失败")
    void longFieldsAreTruncated() {
        ModelEventLogDTO dto = new ModelEventLogDTO();
        dto.setEventType("model_error");
        dto.setModelName("x".repeat(300));
        dto.setCapability("LLM");
        dto.setErrorMessage("E".repeat(2000));
        dto.setTraceId("t".repeat(200));

        newService().logModelEvent(dto);

        ArgumentCaptor<ModelEventLog> captor = ArgumentCaptor.forClass(ModelEventLog.class);
        verify(modelEventLogMapper).insert(captor.capture());
        ModelEventLog saved = captor.getValue();
        assertThat(saved.getModelName()).hasSize(64);
        assertThat(saved.getErrorMessage()).hasSize(1000);
        assertThat(saved.getTraceId()).hasSize(64);
    }
}