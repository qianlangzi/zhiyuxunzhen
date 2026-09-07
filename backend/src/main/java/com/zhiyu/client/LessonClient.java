package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 备课教案 Agent（lesson）· 阶段3 分组门面。
 * 独立于教师助手（teacher）：备课生成/引导/合并/PPT 重 RAG、篇幅大，
 * 需要独立的 temperature / max_tokens / model 覆盖，故拆为单独 Agent 分组。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class LessonClient {

    private final AiHttpClient aiHttpClient;

    /**
     * AI 教学设计生成（智能备课·助教核心）。AI 不可用时返回 null（优雅降级）。
     */
    public Map<String, Object> lessonDesign(String title, String department, String targetGrade,
                                            List<String> teachingGoals, String caseContext,
                                            List<Map<String, Object>> textbookRefs,
                                            String studentProfile, Integer lessonDuration,
                                            List<Map<String, Object>> materialRefs) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title == null ? "" : title);
        body.put("department", department == null ? "" : department);
        body.put("targetGrade", targetGrade == null ? "" : targetGrade);
        body.put("teachingGoals", teachingGoals == null ? List.of() : teachingGoals);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        body.put("textbookRefs", textbookRefs == null ? List.of() : textbookRefs);
        body.put("studentProfile", studentProfile == null ? "" : studentProfile);
        body.put("lessonDuration", lessonDuration == null ? 45 : lessonDuration);
        body.put("materialRefs", materialRefs == null ? List.of() : materialRefs);
        return aiHttpClient.postData("/internal/agent/lesson",
                AiHttpClient.agentEnvelope("lesson_design", body, false));
    }

    /**
     * 向导式备课对话：输入已确认要素 + 用户回答，返回下一个问题/快捷选项/是否完成/需求单。
     */
    public Map<String, Object> lessonGuide(String title, Map<String, Object> confirmed,
                                           String userReply, Integer step) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title == null ? "" : title);
        body.put("confirmed", confirmed == null ? Map.of() : confirmed);
        body.put("userReply", userReply == null ? "" : userReply);
        body.put("step", step == null ? 0 : step);
        return aiHttpClient.postData("/internal/agent/lesson",
                AiHttpClient.agentEnvelope("lesson_guide", body, false));
    }

    /**
     * AI 合并多份教案：以优先级最高教案为主体消解冲突。designs 按优先级从高到低传入。
     * AI 不可用返回 null，调用方回退规则合并（优雅降级）。
     */
    public Map<String, Object> lessonMerge(String title, String department, String targetGrade,
                                           Integer lessonDuration, List<Map<String, Object>> designs) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title == null ? "" : title);
        body.put("department", department == null ? "" : department);
        body.put("targetGrade", targetGrade == null ? "" : targetGrade);
        body.put("lessonDuration", lessonDuration == null ? 45 : lessonDuration);
        body.put("designs", designs == null ? List.of() : designs);
        return aiHttpClient.postData("/internal/agent/lesson",
                AiHttpClient.agentEnvelope("lesson_merge", body, false));
    }

    /**
     * AI 生成课件素材/PPT 提纲。AI 不可用时返回 null。
     */
    public Map<String, Object> lessonPptOutline(String title, String department, String targetGrade,
                                                String designJson, String caseContext, Integer slideCount) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title == null ? "" : title);
        body.put("department", department == null ? "" : department);
        body.put("targetGrade", targetGrade == null ? "" : targetGrade);
        body.put("designJson", designJson == null ? "" : designJson);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        body.put("slideCount", slideCount == null ? 12 : slideCount);
        return aiHttpClient.postData("/internal/agent/lesson",
                AiHttpClient.agentEnvelope("lesson_ppt", body, false));
    }
}