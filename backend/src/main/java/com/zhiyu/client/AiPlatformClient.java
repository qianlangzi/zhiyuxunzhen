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
     * 8. AI 生成 SP 病例草稿（教师端 AI 辅助）
     * POST {ai-base-url}/case/draft
     * 解析 JSON 响应，提取 data 字段返回；AI 不可用时返回 null（非关键能力，优雅降级）
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> generateCaseDraft(String chiefComplaint, String department,
                                                 Integer difficulty, List<String> teachingGoals) {
        Map<String, Object> body = new HashMap<>();
        body.put("chiefComplaint", chiefComplaint);
        body.put("department", department);
        body.put("difficulty", difficulty == null ? 2 : difficulty);
        body.put("teachingGoals", teachingGoals == null ? List.of() : teachingGoals);
        return postData("/case/draft", body);
    }

    /**
     * 9. AI 班级学情洞察（教师端 AI 辅助）
     * POST {ai-base-url}/insight/class
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> classInsight(String className, List<Map<String, Object>> stats,
                                            Map<String, Integer> osceDimensionScores,
                                            List<Map<String, Object>> commonMistakes) {
        Map<String, Object> body = new HashMap<>();
        body.put("className", className == null ? "" : className);
        body.put("stats", stats == null ? List.of() : stats);
        body.put("osceDimensionScores", osceDimensionScores == null ? Map.of() : osceDimensionScores);
        body.put("commonMistakes", commonMistakes == null ? List.of() : commonMistakes);
        return postData("/insight/class", body);
    }

    /**
     * 10. AI 复核辅助（教师端 AI 辅助）
     * POST {ai-base-url}/review/teacher_assist
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> reviewAssist(Long instanceId, String medicalRecordText,
                                            Double aiScore, List<Map<String, Object>> aiMistakes,
                                            String caseContext) {
        Map<String, Object> body = new HashMap<>();
        body.put("instanceId", instanceId);
        body.put("medicalRecordText", medicalRecordText);
        body.put("aiScore", aiScore == null ? 0.0 : aiScore);
        body.put("aiMistakes", aiMistakes == null ? List.of() : aiMistakes);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        return postData("/review/teacher_assist", body);
    }

    /**
     * 11. AI 推荐作业病例（教师端 AI 辅助）
     * POST {ai-base-url}/assignment/recommend
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> recommendCases(Long classId, List<Map<String, Object>> weaknesses,
                                              List<Map<String, Object>> candidateCases) {
        Map<String, Object> body = new HashMap<>();
        body.put("classId", classId);
        body.put("weaknesses", weaknesses == null ? List.of() : weaknesses);
        body.put("candidateCases", candidateCases == null ? List.of() : candidateCases);
        return postData("/assignment/recommend", body);
    }

    /**
     * 12. AI 病例质检（教师端 AI 辅助）
     * POST {ai-base-url}/case/quality_check
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> qualityCheck(Long caseId, String title, String hiddenDisease,
                                            List<String> standardPath, List<Map<String, Object>> presetExams,
                                            List<String> knowledgeTags) {
        Map<String, Object> body = new HashMap<>();
        body.put("caseId", caseId);
        body.put("title", title == null ? "" : title);
        body.put("hiddenDisease", hiddenDisease);
        body.put("standardPath", standardPath == null ? List.of() : standardPath);
        body.put("presetExams", presetExams == null ? List.of() : presetExams);
        body.put("knowledgeTags", knowledgeTags == null ? List.of() : knowledgeTags);
        return postData("/case/quality_check", body);
    }

    /**
     * 13. AI 自动生成练习题（教师端 AI 辅助）
     * POST {ai-base-url}/case/practice_questions
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> practiceQuestions(Long caseId, String hiddenDisease,
                                                 List<String> standardPath, List<String> knowledgeTags) {
        Map<String, Object> body = new HashMap<>();
        body.put("caseId", caseId);
        body.put("hiddenDisease", hiddenDisease);
        body.put("standardPath", standardPath == null ? List.of() : standardPath);
        body.put("knowledgeTags", knowledgeTags == null ? List.of() : knowledgeTags);
        return postData("/case/practice_questions", body);
    }

    /**
     * 14. 影像 AI 读图分析（PRD 9.2 多模态）
     * POST {ai-base-url}/v1/ai/vision/analyze
     * AI 的 vision 接口面向移动端学生 JWT 鉴权，故携带 Authorization: Bearer，而非内部 token。
     * 失败返回 null（优雅降级）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> analyzeVision(Long sessionId, Long studentId, String imageUrl,
                                             List<Double> imageBbox, String studentNote,
                                             String mobileToken) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("image_url", imageUrl);
        if (imageBbox != null && !imageBbox.isEmpty()) body.put("image_bbox", imageBbox);
        if (studentNote != null && !studentNote.isBlank()) body.put("student_note", studentNote);
        try {
            String json = postWithBearer("/v1/ai/vision/analyze", body, mobileToken);
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI影像分析响应中无data字段: sessionId={} resp={}", sessionId, json);
            return null;
        } catch (Exception e) {
            log.warn("AI影像分析失败，返回null: sessionId={} error={}", sessionId, e.getMessage());
            return null;
        }
    }

    /**
     * 15. 错题智能推荐（薄弱知识点 → 个性化补救建议）
     * POST {ai-base-url}/internal/recommend/weakness
     * 失败返回 null（优雅降级，不阻断错题板块）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> recommendWeakness(List<String> knowledgeTags,
                                                 List<String> mistakes) {
        Map<String, Object> body = new HashMap<>();
        body.put("knowledgeTags", knowledgeTags == null ? List.of() : knowledgeTags);
        body.put("mistakes", mistakes == null ? List.of() : mistakes);
        return postData("/internal/recommend/weakness", body);
    }

    /**
     * 统一的 POST 请求并解析 data 字段；AI 不可用或返回异常时返回 null（不抛异常，支持优雅降级）
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> postData(String path, Map<String, Object> body) {
        try {
            String json = post(path, body);
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI中台响应中无data字段: {} resp={}", path, json);
            return null;
        } catch (Exception e) {
            log.warn("AI中台调用失败，返回null: {} error={}", path, e.getMessage());
            return null;
        }
    }

    /**
     * 携带移动端 JWT（Authorization: Bearer）的 POST 请求封装；失败返回 null（优雅降级）
     */
    private String postWithBearer(String path, Map<String, Object> body, String bearer) {
        String url = baseUrl + path;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            if (bearer != null && !bearer.isBlank()) {
                headers.set(HttpHeaders.AUTHORIZATION, bearer.startsWith("Bearer ") ? bearer : "Bearer " + bearer);
            }
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);
            ResponseEntity<String> resp = restTemplate.exchange(url, HttpMethod.POST, entity, String.class);
            return resp.getBody();
        } catch (RestClientException e) {
            log.error("调用AI中台失败: POST {} error={}", url, e.getMessage());
            return null;
        } catch (Exception e) {
            log.error("调用AI中台未知异常: POST {} error={}", url, e.getMessage(), e);
            return null;
        }
    }

    /**
     * 统一的 POST 请求封装
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
