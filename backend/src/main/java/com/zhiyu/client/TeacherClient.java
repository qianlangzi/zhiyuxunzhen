package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 教师助手 Agent（teacher）· 阶段3 分组门面。
 * 教师端业务能力：病例草稿、班级洞察、复核辅助、病例推荐、质检、出题。
 * 备课（教案生成/引导/合并/PPT）已拆分至独立分组 lesson，见 LessonClient。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherClient {

    private final AiHttpClient aiHttpClient;

    /**
     * AI 生成 SP 病例草稿：走 strict 版本，AI 返回错误时透传真实 message 便于诊断。
     */
    public Map<String, Object> generateCaseDraft(String chiefComplaint, String department,
                                                 Integer difficulty, List<String> teachingGoals,
                                                 String remark) {
        Map<String, Object> body = new HashMap<>();
        body.put("chiefComplaint", chiefComplaint);
        body.put("department", department);
        body.put("difficulty", difficulty == null ? 2 : difficulty);
        body.put("teachingGoals", teachingGoals == null ? List.of() : teachingGoals);
        if (remark != null && !remark.isBlank()) body.put("remark", remark);
        return aiHttpClient.postDataStrict("/internal/agent/teacher",
                AiHttpClient.agentEnvelope("case_draft", body, false));
    }

    /**
     * AI 班级学情洞察。
     */
    public Map<String, Object> classInsight(String className, List<Map<String, Object>> stats,
                                            Map<String, Integer> osceDimensionScores,
                                            List<Map<String, Object>> commonMistakes) {
        Map<String, Object> body = new HashMap<>();
        body.put("className", className == null ? "" : className);
        body.put("stats", stats == null ? List.of() : stats);
        body.put("osceDimensionScores", osceDimensionScores == null ? Map.of() : osceDimensionScores);
        body.put("commonMistakes", commonMistakes == null ? List.of() : commonMistakes);
        return aiHttpClient.postData("/internal/agent/teacher",
                AiHttpClient.agentEnvelope("class_insight", body, false));
    }

    /**
     * AI 复核辅助。
     */
    public Map<String, Object> reviewAssist(Long instanceId, String medicalRecordText,
                                            Double aiScore, List<Map<String, Object>> aiMistakes,
                                            String caseContext) {
        Map<String, Object> body = new HashMap<>();
        body.put("instanceId", instanceId);
        body.put("medicalRecordText", medicalRecordText);
        body.put("aiScore", aiScore == null ? 0.0 : aiScore);
        body.put("aiMistakes", aiMistakes == null ? List.of() : aiMistakes);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        return aiHttpClient.postData("/internal/agent/teacher",
                AiHttpClient.agentEnvelope("review_assist", body, false));
    }

    /**
     * AI 推荐作业病例。
     */
    public Map<String, Object> recommendCases(Long classId, List<Map<String, Object>> weaknesses,
                                              List<Map<String, Object>> candidateCases) {
        Map<String, Object> body = new HashMap<>();
        body.put("classId", classId);
        body.put("weaknesses", weaknesses == null ? List.of() : weaknesses);
        body.put("candidateCases", candidateCases == null ? List.of() : candidateCases);
        return aiHttpClient.postData("/internal/agent/teacher",
                AiHttpClient.agentEnvelope("recommend_cases", body, false));
    }

    /**
     * AI 病例质检。
     */
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
        return aiHttpClient.postData("/internal/agent/teacher",
                AiHttpClient.agentEnvelope("quality_check", body, false));
    }

    /**
     * 病例素材智能推荐：教师构建病例时建议应准备的多模态材料清单。
     */
    public Map<String, Object> materialAdvice(Long caseId, String title, String department,
                                              String complaint, String hiddenDisease,
                                              String presentIllness, List<String> existingExams) {
        Map<String, Object> body = new HashMap<>();
        body.put("caseId", caseId == null ? 0 : caseId);
        body.put("title", title == null ? "" : title);
        body.put("department", department == null ? "" : department);
        body.put("complaint", complaint == null ? "" : complaint);
        body.put("hiddenDisease", hiddenDisease == null ? "" : hiddenDisease);
        body.put("presentIllness", presentIllness == null ? "" : presentIllness);
        body.put("existingExams", existingExams == null ? List.of() : existingExams);
        return aiHttpClient.postData("/internal/agent/teacher",
                AiHttpClient.agentEnvelope("material_advice", body, false));
    }

    /**
     * AI 自动生成练习题。
     */
    public Map<String, Object> practiceQuestions(Long caseId, String hiddenDisease,
                                                 List<String> standardPath, List<String> knowledgeTags) {
        Map<String, Object> body = new HashMap<>();
        body.put("caseId", caseId);
        body.put("hiddenDisease", hiddenDisease);
        body.put("standardPath", standardPath == null ? List.of() : standardPath);
        body.put("knowledgeTags", knowledgeTags == null ? List.of() : knowledgeTags);
        return aiHttpClient.postData("/internal/agent/teacher",
                AiHttpClient.agentEnvelope("practice_questions", body, false));
    }
}