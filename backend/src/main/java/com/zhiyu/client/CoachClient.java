package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 学习教练 Agent（coach）· 阶段3 分组门面。
 * 归并学习补救/诊断/组卷/预警类调用：学习路径、薄弱点推荐、错题归因、学情诊断、组卷、预警干预。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CoachClient {

    private final AiHttpClient aiHttpClient;

    /**
     * 生成学习路径（学习教练 Agent）：携带学生事实快照，AI 生成个性化路径。失败返回 null（优雅降级）。
     */
    public String generateLearningPath(Long studentId, Map<String, Object> facts) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        if (facts != null && !facts.isEmpty()) {
            body.put("facts", facts);
        }
        return aiHttpClient.post("/internal/agent/coach",
                AiHttpClient.agentEnvelope("learning_path", body, false));
    }

    /**
     * 错题智能推荐（薄弱知识点 → 补救建议）。失败返回 null（优雅降级，不阻断错题板块）。
     */
    public Map<String, Object> recommendWeakness(List<String> knowledgeTags,
                                                 List<String> mistakes,
                                                 List<String> candidateTextbooks,
                                                 List<String> candidateQuestions) {
        Map<String, Object> body = new HashMap<>();
        body.put("knowledgeTags", knowledgeTags == null ? List.of() : knowledgeTags);
        body.put("mistakes", mistakes == null ? List.of() : mistakes);
        body.put("candidateTextbooks", candidateTextbooks == null ? List.of() : candidateTextbooks);
        body.put("candidateQuestions", candidateQuestions == null ? List.of() : candidateQuestions);
        return aiHttpClient.postData("/internal/agent/coach",
                AiHttpClient.agentEnvelope("recommend_weakness", body, false));
    }

    /**
     * 错题 AI 归因：AI 不可用时 data 为 status=DEGRADED 降级对象（仍返回 code=0）。
     */
    public Map<String, Object> analyzeMistake(Long mistakeId, Long studentId, String mistakeType,
                                              String knowledgeTag, String caseTitle, String question,
                                              String studentAnswer, String standardAnswer,
                                              String evidence) {
        return analyzeMistake(mistakeId, studentId, mistakeType, knowledgeTag, caseTitle, question,
                studentAnswer, standardAnswer, evidence, null, null, null);
    }

    /**
     * 错题归因（增强）：额外支持主观题模式与批阅明细。
     *
     * @param questionType   objective=客观题/问诊实操（临床推理五阶段分叉）；subjective=简答论述
     * @param score          主观题得分（0-100），客观题传 null
     * @param essayMistakes  主观题批阅错误明细，客观题传 null
     */
    public Map<String, Object> analyzeMistake(Long mistakeId, Long studentId, String mistakeType,
                                              String knowledgeTag, String caseTitle, String question,
                                              String studentAnswer, String standardAnswer,
                                              String evidence, String questionType, Double score,
                                              List<Map<String, Object>> essayMistakes) {
        Map<String, Object> body = new HashMap<>();
        body.put("mistakeId", mistakeId);
        body.put("studentId", studentId);
        body.put("mistakeType", mistakeType == null ? "" : mistakeType);
        if (knowledgeTag != null) body.put("knowledgeTag", knowledgeTag);
        if (caseTitle != null) body.put("caseTitle", caseTitle);
        if (question != null && !question.isBlank()) body.put("question", question);
        if (studentAnswer != null && !studentAnswer.isBlank()) body.put("studentAnswer", studentAnswer);
        if (standardAnswer != null && !standardAnswer.isBlank()) body.put("standardAnswer", standardAnswer);
        if (evidence != null && !evidence.isBlank()) body.put("evidence", evidence);
        body.put("questionType", questionType == null || questionType.isBlank() ? "objective" : questionType);
        if (score != null) body.put("score", score);
        if (essayMistakes != null && !essayMistakes.isEmpty()) body.put("essayMistakes", essayMistakes);
        return aiHttpClient.postData("/internal/agent/coach",
                AiHttpClient.agentEnvelope("mistake_analyze", body, false));
    }

    /**
     * 薄弱点学情诊断：AI 不可用时 data 为 status=DEGRADED 降级对象，调用方回退纯统计。
     */
    public Map<String, Object> weaknessDiagnosis(Long studentId,
                                                 List<Map<String, Object>> weaknesses,
                                                 List<Map<String, Object>> mistakes) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        body.put("weaknesses", weaknesses == null ? List.of() : weaknesses);
        body.put("mistakes", mistakes == null ? List.of() : mistakes);
        return aiHttpClient.postData("/internal/agent/coach",
                AiHttpClient.agentEnvelope("weakness_diagnosis", body, false));
    }

    /**
     * AI 组卷（组卷 Agent · P2-4）：AI 不可用时 data 为 status=DEGRADED 降级对象，调用方回退规则组卷。
     */
    public Map<String, Object> generatePaper(Long studentId, Integer count, Integer difficulty,
                                             List<String> focusTags,
                                             List<Map<String, Object>> candidates) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        body.put("count", count == null ? 10 : count);
        if (difficulty != null) body.put("difficulty", difficulty);
        body.put("focusTags", focusTags == null ? List.of() : focusTags);
        body.put("candidates", candidates == null ? List.of() : candidates);
        return aiHttpClient.postData("/internal/agent/coach",
                AiHttpClient.agentEnvelope("paper_generate", body, false));
    }

    /**
     * 学情预警干预建议（助教：学情诊断）。AI 不可用时返回 null（优雅降级）。
     */
    public Map<String, Object> alertIntervention(String studentName,
                                                 List<Map<String, Object>> riskRules,
                                                 List<Map<String, Object>> weaknesses,
                                                 List<Map<String, Object>> recentMistakes,
                                                 List<Map<String, Object>> recommendedCases,
                                                 List<Map<String, Object>> textbookRefs) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentName", studentName == null ? "" : studentName);
        body.put("riskRules", riskRules == null ? List.of() : riskRules);
        body.put("weaknesses", weaknesses == null ? List.of() : weaknesses);
        body.put("recentMistakes", recentMistakes == null ? List.of() : recentMistakes);
        body.put("recommendedCases", recommendedCases == null ? List.of() : recommendedCases);
        body.put("textbookRefs", textbookRefs == null ? List.of() : textbookRefs);
        return aiHttpClient.postData("/internal/agent/coach",
                AiHttpClient.agentEnvelope("alert", body, false));
    }
}