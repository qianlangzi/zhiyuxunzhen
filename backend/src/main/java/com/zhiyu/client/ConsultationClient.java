package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 问诊咨询 Agent（consultation）· 阶段3 分组门面。
 * 归并问诊聊天类调用：流式 / 同步 / SP 开场白。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ConsultationClient {

    private final AiHttpClient aiHttpClient;

    /**
     * 问诊聊天流式转发（SSE）。必须在 ResponseExtractor 回调内读取并转发，避免 "stream is closed"。
     */
    public void streamChat(Long sessionId, Long studentId, Long caseId, String message, SseEmitter emitter) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        body.put("messages", List.of(Map.of("role", "student", "content", message)));
        aiHttpClient.postSse("/internal/agent/consultation",
                AiHttpClient.agentEnvelope("stream", body, true), emitter, "AI服务调用异常");
    }

    /**
     * 问诊聊天同步转发：解析 data 返回；失败抛 BizException(AI_SERVICE_ERROR)。
     */
    public Map<String, Object> chatSync(Long sessionId, Long studentId, Long caseId, String message) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        body.put("messages", List.of(Map.of("role", "student", "content", message)));
        return aiHttpClient.postDataStrict("/internal/agent/consultation",
                AiHttpClient.agentEnvelope("sync", body, false));
    }

    /**
     * SP 开场白：返回 {@code data.reply}；AI 不可用时返回 null（调用方降级）。
     */
    public String chatOpening(Long sessionId, Long studentId, Long caseId) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        // ChatRequest 要求 messages 字段（必填）；开场白业务忽略其内容，传空数组仅为通过入参校验。
        body.put("messages", List.of());
        Map<String, Object> result = aiHttpClient.postData("/internal/agent/consultation",
                AiHttpClient.agentEnvelope("opening", body, false));
        if (result == null) return null;
        Object reply = result.get("reply");
        return reply == null ? null : reply.toString();
    }
}