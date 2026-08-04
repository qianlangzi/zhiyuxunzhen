package com.zhiyu.client;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 中台客户端（PRD 9.3）
 * 封装调用 FastAPI 的 5 个出站接口，设置 30s 超时，异常时抛 BizException(AI_SERVICE_ERROR)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiPlatformClient {

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${zhiyu.ai.base-url}")
    private String baseUrl;

    @Value("${zhiyu.ai.internal-token}")
    private String internalToken;

    /**
     * 1. 大病历批阅（PRD 9.3）
     * POST {ai-base-url}/review/medical_record
     */
    public String reviewMedicalRecord(Long instanceId, String medicalRecordText) {
        Map<String, Object> body = new HashMap<>();
        body.put("instanceId", instanceId);
        body.put("medicalRecordText", medicalRecordText);
        return post("/review/medical_record", body);
    }

    /**
     * 2. 生成学习路径（PRD 9.3）
     * POST {ai-base-url}/learning_path/generate
     */
    public String generateLearningPath(Long studentId) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        return post("/learning_path/generate", body);
    }

    /**
     * 3. 教材向量化嵌入（PRD 9.3）
     * POST {ai-base-url}/embed/textbook
     */
    public String embedTextbook(Long textbookId, String fileUrl) {
        Map<String, Object> body = new HashMap<>();
        body.put("textbookId", textbookId);
        body.put("fileUrl", fileUrl);
        return post("/embed/textbook", body);
    }

    /**
     * 4. 每日一例评估（PRD 9.3）
     * POST {ai-base-url}/daily_case/evaluate
     */
    public String evaluateDailyCase(Long studentId, Long caseId, String answer,
                                    String caseSummary, String keyFindings, String standardAnswer) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        body.put("caseId", caseId);
        body.put("answer", answer);
        if (caseSummary != null) body.put("caseSummary", caseSummary);
        if (keyFindings != null) body.put("keyFindings", keyFindings);
        if (standardAnswer != null) body.put("standardAnswer", standardAnswer);
        return post("/daily_case/evaluate", body);
    }

    /**
     * 6. 会话评估与归档（PRD 9.3）
     * POST {ai-base-url}/session/evaluate_and_archive
     */
    public String evaluateAndArchiveSession(Long sessionId, Long studentId) {
        Map<String, Object> body = new HashMap<>();
        body.put("sessionId", sessionId);
        body.put("studentId", studentId);
        return post("/session/evaluate_and_archive", body);
    }

    /**
     * 5. 生成批阅报告 PDF（PRD 9.3）
     * POST {ai-base-url}/report/generate_review_pdf
     * 解析 JSON 响应，提取 data 字段返回；AI 不可用时返回 null
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> generateReviewPdf(Long sessionId) {
        Map<String, Object> body = new HashMap<>();
        body.put("sessionId", sessionId);
        try {
            String json = post("/report/generate_review_pdf", body);
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI生成报告响应中无data字段: sessionId={} resp={}", sessionId, json);
            return null;
        } catch (Exception e) {
            log.warn("AI生成报告失败，返回null: sessionId={} error={}", sessionId, e.getMessage());
            return null;
        }
    }

    /**
     * 7. 问诊聊天同步转发（PRD 5.2 / 9.3）
     * POST {ai-base-url}/internal/chat/sync
     * 解析 JSON 响应，提取 data 字段返回；失败抛 BizException(AI_SERVICE_ERROR)
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> chatSync(Long sessionId, Long studentId, Long caseId, String message) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        body.put("messages", List.of(Map.of("role", "student", "content", message)));
        try {
            String json = post("/internal/chat/sync", body);
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI问诊同步响应中无data字段: sessionId={} resp={}", sessionId, json);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI问诊返回数据异常");
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("AI问诊同步调用失败: sessionId={} error={}", sessionId, e.getMessage());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务调用异常: " + e.getMessage());
        }
    }

    /**
     * 统一 POST 请求封装
     */
    private String post(String path, Map<String, Object> body) {
        String url = baseUrl + path;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("X-Internal-Token", internalToken);
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

            log.info("调用AI中台: POST {} body={}", url, body);
            ResponseEntity<String> resp = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
            log.info("AI中台响应: {} status={}", url, resp.getStatusCode());

            return resp.getBody();
        } catch (RestClientException e) {
            log.error("调用AI中台失败: POST {} error={}", url, e.getMessage());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务调用异常: " + e.getMessage());
        } catch (Exception e) {
            log.error("调用AI中台未知异常: POST {} error={}", url, e.getMessage(), e);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务调用异常");
        }
    }
}
