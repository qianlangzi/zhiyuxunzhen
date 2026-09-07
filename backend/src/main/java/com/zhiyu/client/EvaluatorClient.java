package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 评测批阅 Agent（evaluator）· 阶段3 分组门面。
 * 归并批阅/判题类调用：大病历批阅、每日一例、会话评估归档、主观题批阅。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EvaluatorClient {

    private final AiHttpClient aiHttpClient;

    /**
     * 大病历批阅（PRD 9.3）。
     */
    public String reviewMedicalRecord(Long instanceId, String medicalRecordText) {
        Map<String, Object> body = new HashMap<>();
        body.put("instanceId", instanceId);
        body.put("medicalRecordText", medicalRecordText);
        return aiHttpClient.post("/internal/agent/evaluator",
                AiHttpClient.agentEnvelope("medical_record", body, false));
    }

    /**
     * 每日一例评估（PRD 9.3）。
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
        return aiHttpClient.post("/internal/agent/evaluator",
                AiHttpClient.agentEnvelope("daily_case", body, false));
    }

    /**
     * 会话评估与归档：AI 出错时以 HTTP 200 + code!=200 返回，严格模式避免 finish() 误判成功。
     */
    public void evaluateAndArchiveSession(Long sessionId, Long studentId) {
        Map<String, Object> body = new HashMap<>();
        body.put("sessionId", sessionId);
        body.put("studentId", studentId);
        aiHttpClient.postDataStrict("/internal/agent/evaluator",
                AiHttpClient.agentEnvelope("session", body, false));
    }

    /**
     * 主观题（简答/论述）批阅：按教师配置评分要点批阅，返回维度评分与改进建议。
     */
    public Map<String, Object> reviewEssay(String question, String scoringPoints,
                                           String studentAnswer, String caseContext,
                                           List<Map<String, Object>> textbookRefs) {
        Map<String, Object> body = new HashMap<>();
        body.put("question", question == null ? "" : question);
        body.put("scoringPoints", scoringPoints == null ? "" : scoringPoints);
        body.put("studentAnswer", studentAnswer == null ? "" : studentAnswer);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        body.put("textbookRefs", textbookRefs == null ? List.of() : textbookRefs);
        return aiHttpClient.postData("/internal/agent/evaluator",
                AiHttpClient.agentEnvelope("essay", body, false));
    }

    /**
     * 每日病历 · 段落教练：三级提示梯度（追问→定向提示→示范片段），绝不代写。
     */
    public Map<String, Object> mrSegmentHint(Long scheduleId, Long studentId, String segmentKey,
                                             String segmentName, String segmentSpec, int hintLevel,
                                             String draft, String caseSummary, String keyFindings,
                                             List<String> materials) {
        Map<String, Object> body = new HashMap<>();
        body.put("scheduleId", scheduleId);
        body.put("studentId", studentId);
        body.put("segmentKey", segmentKey == null ? "" : segmentKey);
        body.put("segmentName", segmentName == null ? "" : segmentName);
        body.put("segmentSpec", segmentSpec == null ? "" : segmentSpec);
        body.put("hintLevel", hintLevel);
        body.put("draft", draft == null ? "" : draft);
        body.put("caseSummary", caseSummary == null ? "" : caseSummary);
        body.put("keyFindings", keyFindings == null ? "" : keyFindings);
        body.put("materials", materials == null ? List.of() : materials);
        return aiHttpClient.postData("/internal/agent/evaluator",
                AiHttpClient.agentEnvelope("mr_hint", body, false));
    }

    /**
     * 每日病历 · 结构化批阅：九段独立评分 + 缺陷打标 + 置信度。
     */
    public Map<String, Object> mrReview(Long recordId, Long scheduleId, Long studentId,
                                        Map<String, String> record, String caseContext,
                                        String standardAnswer) {
        Map<String, Object> body = new HashMap<>();
        body.put("recordId", recordId == null ? 0 : recordId);
        body.put("scheduleId", scheduleId);
        body.put("studentId", studentId);
        body.put("record", record == null ? Map.of() : record);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        body.put("standardAnswer", standardAnswer == null ? "" : standardAnswer);
        return aiHttpClient.postData("/internal/agent/evaluator",
                AiHttpClient.agentEnvelope("mr_review", body, false));
    }
}