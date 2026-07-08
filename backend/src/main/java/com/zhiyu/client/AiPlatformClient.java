package com.zhiyu.client;

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
    public String evaluateDailyCase(Long studentId, Long caseId, String answer) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        body.put("caseId", caseId);
        body.put("answer", answer);
        return post("/daily_case/evaluate", body);
    }

    /**
     * 5. 生成批阅报告 PDF（PRD 9.3）
     * POST {ai-base-url}/report/generate_review_pdf
     */
    public String generateReviewPdf(Long sessionId) {
        Map<String, Object> body = new HashMap<>();
        body.put("sessionId", sessionId);
        return post("/report/generate_review_pdf", body);
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
