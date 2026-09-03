package com.zhiyu.service.impl;

import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.entity.ModelEventLog;
import com.zhiyu.mapper.AiAgentMapper;
import com.zhiyu.mapper.AiPromptMapper;
import com.zhiyu.mapper.AiRuntimeConfigMapper;
import com.zhiyu.mapper.ModelEventLogMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.vo.ModelEventLogVO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * 「最近模型事件」查询单测
 *
 * 覆盖：
 * 1. 实体 → VO 映射完整（recovered/capability/traceId/detailJson 等）
 * 2. 空结果返回空列表
 */
@ExtendWith(MockitoExtension.class)
class AiConfigRecentModelEventsTest {

    @Mock
    private AiPromptMapper aiPromptMapper;
    @Mock
    private AiAgentMapper aiAgentMapper;
    @Mock
    private AiRuntimeConfigMapper aiRuntimeConfigMapper;
    @Mock
    private AuditLogService auditLogService;
    @Mock
    private AiPlatformClient aiPlatformClient;
    @Mock
    private ModelEventLogMapper modelEventLogMapper;

    private AiConfigServiceImpl newService() {
        return new AiConfigServiceImpl(aiPromptMapper, aiAgentMapper, aiRuntimeConfigMapper,
                auditLogService, aiPlatformClient, modelEventLogMapper);
    }

    @Test
    @DisplayName("实体正确映射为 VO，恢复标记与各结构化字段完整传递")
    void mapsEntitiesToVos() {
        LocalDateTime ts = LocalDateTime.of(2026, 8, 26, 10, 30);
        ModelEventLog error = new ModelEventLog();
        error.setId(1L);
        error.setEventType("model_error");
        error.setModelName("deepseek-chat");
        error.setCapability("LLM");
        error.setErrorMessage("模型调用失败");
        error.setDetailJson("{\"fallback\":true}");
        error.setTraceId("trace-1");
        error.setRecovered(false);
        error.setCreatedAt(ts);

        ModelEventLog recovered = new ModelEventLog();
        recovered.setId(2L);
        recovered.setEventType("recovered");
        recovered.setModelName("deepseek-chat");
        recovered.setCapability("LLM");
        recovered.setErrorMessage("模型恢复正常");
        recovered.setRecovered(true);
        recovered.setCreatedAt(ts.plusSeconds(5));

        when(modelEventLogMapper.selectList(any())).thenReturn(List.of(recovered, error));

        List<ModelEventLogVO> vos = newService().recentModelEvents(20);

        assertThat(vos).hasSize(2);
        assertThat(vos.get(0).getEventType()).isEqualTo("recovered");
        assertThat(vos.get(0).getRecovered()).isTrue();
        assertThat(vos.get(1).getEventType()).isEqualTo("model_error");
        assertThat(vos.get(1).getRecovered()).isFalse();
        assertThat(vos.get(1).getCapability()).isEqualTo("LLM");
        assertThat(vos.get(1).getTraceId()).isEqualTo("trace-1");
        assertThat(vos.get(1).getDetailJson()).isEqualTo("{\"fallback\":true}");
        assertThat(vos.get(1).getCreatedAt()).isEqualTo(ts);
    }

    @Test
    @DisplayName("空结果返回空列表而非 null")
    void emptyResultReturnsEmptyList() {
        when(modelEventLogMapper.selectList(any())).thenReturn(List.of());
        List<ModelEventLogVO> vos = newService().recentModelEvents(20);
        assertThat(vos).isEmpty();
    }
}