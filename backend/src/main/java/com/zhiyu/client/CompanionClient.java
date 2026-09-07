package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 学习陪伴 Agent（companion）· 阶段3 分组门面。
 * 归并 AI 学伴调用：同步 / 流式（SSE）。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CompanionClient {

    private final AiHttpClient aiHttpClient;

    /**
     * AI 学伴 · 同步。context 为业务中台组装的学生学情上下文（区别于 SP 病人角色）。
     */
    public Map<String, Object> companionSync(String message,
                                             List<Map<String, String>> history,
                                             Map<String, Object> context,
                                             String imageUrl,
                                             Long studentId,
                                             Long conversationId) {
        return aiHttpClient.postDataStrict("/internal/agent/companion",
                AiHttpClient.agentEnvelope("sync",
                        buildBody(message, history, context, imageUrl, studentId, conversationId), false));
    }

    /**
     * AI 学伴 · 流式（SSE），在 ResponseExtractor 回调内读取并转发，避免 "stream is closed"。
     */
    public void companionStream(String message,
                                List<Map<String, String>> history,
                                Map<String, Object> context,
                                String imageUrl,
                                Long studentId,
                                Long conversationId,
                                SseEmitter emitter) throws Exception {
        aiHttpClient.postSse("/internal/agent/companion",
                AiHttpClient.agentEnvelope("stream",
                        buildBody(message, history, context, imageUrl, studentId, conversationId), true),
                emitter, "AI学伴服务异常");
    }

    private Map<String, Object> buildBody(String message,
                                          List<Map<String, String>> history,
                                          Map<String, Object> context,
                                          String imageUrl,
                                          Long studentId,
                                          Long conversationId) {
        Map<String, Object> body = new HashMap<>();
        body.put("student_id", studentId);
        if (conversationId != null) {
            body.put("session_id", conversationId);
        }
        body.put("message", message);
        body.put("history", history == null ? List.of() : history);
        if (StringUtils.hasText(imageUrl)) {
            body.put("image_url", imageUrl);
        }
        if (context != null && !context.isEmpty()) {
            body.put("context", context);
        }
        return body;
    }
}