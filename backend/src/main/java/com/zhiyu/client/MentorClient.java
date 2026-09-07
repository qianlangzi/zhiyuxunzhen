package com.zhiyu.client;

import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 导师 Agent（mentor）· 阶段3 分组门面。
 * 导师按需小结：思维树 + 苏格拉底提示。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MentorClient {

    private final AiHttpClient aiHttpClient;

    /**
     * 导师按需小结：AI 侧回查会话上下文 → mentor_agent.update_tree → {tree, hint}。
     * 返回 data 字段；AI 不可用时抛 BizException（移动端优雅降级提示）。
     */
    public Map<String, Object> sessionMentor(Long sessionId, Long studentId, Long caseId) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        // ChatRequest.messages 兼容字段（AI 侧已放宽为可选，传空数组保持旧协议兼容）
        body.put("messages", List.of());
        Map<String, Object> result = aiHttpClient.postData(
                "/internal/agent/mentor", AiHttpClient.agentEnvelope("update_tree", body, false));
        if (result == null) {
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI 导师小结暂不可用，请稍后再试");
        }
        return result;
    }
}