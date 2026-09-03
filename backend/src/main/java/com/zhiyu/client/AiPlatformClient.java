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
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
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
     * 2. 生成学习路径（PRD 9.3）— 学习教练 Agent
     * POST {ai-base-url}/learning_path/generate
     * 携带业务中台组装的学生事实快照（薄弱点/错题/候选资源），AI 据此生成个性化路径。
     * 返回 AI 的 data JSON 字符串；失败返回 null（优雅降级）。
     */
    public String generateLearningPath(Long studentId, Map<String, Object> facts) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        if (facts != null && !facts.isEmpty()) {
            body.put("facts", facts);
        }
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
     * 使用严格模式：AI 中台出错时以 HTTP 200 + code!=200 返回（如评估器/模型不可用、
     * 上下文获取失败），若静默忽略会让 finish() 误判成功——会话 status=1 但
     * osce_score_json/final_report 永久为空、且不进入 status=2 待重试（2026-09-02 根因）。
     */
    public void evaluateAndArchiveSession(Long sessionId, Long studentId) {
        Map<String, Object> body = new HashMap<>();
        body.put("sessionId", sessionId);
        body.put("studentId", studentId);
        postDataStrict("/session/evaluate_and_archive", body);
    }

    /**
     * 7c. SP 开场白（PRD 5.2 优化）· 学生首次进入问诊会话时调用，触发 SP 用 1~2 句
     * 病人口吻主动开场。与 /internal/chat/sync 区别：开场不写 ChatMessageLog、不送
     * mentor_update，仅生成一句话让移动端首屏可见。
     * 返回 {@code data.reply}；AI 不可用时返回 null（调用方按降级文案处理）。
     */
    public String chatOpening(Long sessionId, Long studentId, Long caseId) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        // ChatRequest 模型要求 messages 字段（必填）；开场白业务忽略其内容（history 由 AI 端置空），
        // 这里传空数组仅为通过 AI 中台入参校验，否则会触发 422 → postData 返回 null → 降级兜底。
        body.put("messages", List.of());
        Map<String, Object> result = postData("/internal/chat/opening", body);
        if (result == null) return null;
        Object reply = result.get("reply");
        return reply == null ? null : reply.toString();
    }

    /**
     * 7d. 导师按需小结（2026-09-03）：学生主动请求思维树 / 苏格拉底提示时调用。
     * POST {ai-base-url}/internal/chat/mentor
     * AI 侧回查会话上下文（病例 + 历史）→ mentor_agent.update_tree → {tree, hint}。
     * 返回 data 字段；AI 不可用时返回 null（移动端优雅降级提示）。
     */
    public Map<String, Object> sessionMentor(Long sessionId, Long studentId, Long caseId) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        // ChatRequest.messages 兼容字段（AI 侧已放宽为可选，传空数组保持旧协议兼容）
        body.put("messages", List.of());
        Map<String, Object> result = postData("/internal/chat/mentor", body);
        if (result == null) {
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI 导师小结暂不可用，请稍后再试");
        }
        return result;
    }

    /**
     * 7b. 问诊聊天流式转发（PRD 5.2 / 9.3）
     * POST {ai-base-url}/internal/chat/stream
     * 在 RestTemplate 的 ResponseExtractor 回调内直接读取 AI 中台原生 SSE 流并
     * 逐行转发给 SseEmitter，由上层控制器透传给移动端。
     * <p>
     * 重要：不能把 {@code response.getBody()} 返回到回调外再读——RestTemplate 在
     * ResponseExtractor 返回后会关闭底层连接/流，外部读到的 InputStream 已是 closed
     * （典型异常 "stream is closed"）。因此必须在回调内完成读取与转发。
     * 事件契约：message / tree / stage / socrates / safety / citation / status / error / done。
     * 与 chatSync 平行：sync 聚合为 JSON，stream 透传 SSE。前端可选流式或同步。
     */
    public void streamChat(Long sessionId, Long studentId, Long caseId, String message, SseEmitter emitter) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("student_id", studentId);
        body.put("case_id", caseId);
        body.put("messages", List.of(Map.of("role", "student", "content", message)));
        String url = baseUrl + "/internal/chat/stream";
        try {
            String json = objectMapper.writeValueAsString(body);
            restTemplate.execute(url, HttpMethod.POST,
                    request -> {
                        request.getHeaders().setContentType(MediaType.APPLICATION_JSON);
                        request.getHeaders().set("X-Internal-Token", internalToken);
                        request.getHeaders().set("Cache-Control", "no-cache");
                        request.getHeaders().set("Accept", "text/event-stream");
                        request.getBody().write(json.getBytes(StandardCharsets.UTF_8));
                    },
                    response -> {
                        if (response.getStatusCode().value() != 200) {
                            throw new BizException(ResultCode.AI_SERVICE_ERROR,
                                    "AI 流式服务异常: HTTP " + response.getStatusCode().value());
                        }
                        // 在回调内读取，流尚未被 RestTemplate 关闭
                        forwardSseToEmitter(response.getBody(), emitter);
                        return null;
                    });
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("调用AI流式失败: POST {} error={}", url, e.getMessage(), e);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务调用异常: " + e.getMessage());
        }
    }

    /**
     * 把 AI 中台返回的 SSE 原始字节流按行解析后转发到客户端 SseEmitter。
     * 事件格式：``event: <name>\ndata: <json>\n\n``，与 sse_starlette 默认输出对齐。
     */
    private static void forwardSseToEmitter(InputStream upstream, SseEmitter emitter) throws IOException {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(upstream, StandardCharsets.UTF_8))) {
            String line;
            String event = null;
            while ((line = reader.readLine()) != null) {
                if (line.isBlank()) {
                    event = null;
                    continue;
                }
                if (line.startsWith("event:")) {
                    event = line.substring("event:".length()).trim();
                } else if (line.startsWith("data:") && event != null) {
                    String data = line.substring("data:".length()).trim();
                    try {
                        if ("done".equals(event)) {
                            emitter.send(SseEmitter.event().name(event).data(data));
                            emitter.complete();
                            return;
                        }
                        emitter.send(SseEmitter.event().name(event).data(data));
                    } catch (Exception ex) {
                        log.debug("SSE send 中断（前端可能已离开）: {}", ex.getMessage());
                        emitter.complete();
                        return;
                    }
                }
            }
            emitter.complete();
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
                                                 Integer difficulty, List<String> teachingGoals,
                                                 String remark) {
        Map<String, Object> body = new HashMap<>();
        body.put("chiefComplaint", chiefComplaint);
        body.put("department", department);
        body.put("difficulty", difficulty == null ? 2 : difficulty);
        body.put("teachingGoals", teachingGoals == null ? List.of() : teachingGoals);
        if (remark != null && !remark.isBlank()) body.put("remark", remark);
        // 走 strict 版本：AI 返回错误时透传真实 message（如"大模型未配置"），
        // 方便移动端给出可操作诊断，而不是笼统的"AI 暂不可用"。
        return postDataStrict("/case/draft", body);
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
     * 15c. AI 学习学伴（P1-2，学习陪伴）· 同步
     * POST {ai-base-url}/internal/companion/sync
     * 学生与学伴闲聊 + 策略建议；context 为业务中台组装的学生学情上下文
     * （薄弱点/近期错题/进度），学伴据此给个性化建议（区别于 SP 病人角色）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> companionSync(String message,
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
        try {
            String json = post("/internal/companion/sync", body);
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI学伴响应中无data字段: message={} resp={}", message, json);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI学伴返回数据异常");
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("AI学伴调用失败: error={}", e.getMessage());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI学伴服务异常: " + e.getMessage());
        }
    }

    /**
     * 15d. AI 学习学伴（P1-2）· 流式（SSE）
     * POST {ai-base-url}/internal/companion/stream
     * 在 RestTemplate 的 ResponseExtractor 回调内读取 AI 中台 SSE 流并逐行转发给
     * SseEmitter（与 streamChat 同一转发器）。
     * <p>
     * 重要：不能把 {@code response.getBody()} 返回到回调外再读——RestTemplate 在
     * ResponseExtractor 返回后会关闭底层连接/流，外部读到的 InputStream 已 closed
     * （"stream is closed"）。必须在回调内完成读取与转发。
     * 事件契约：message / status / safety / error / done。
     */
    public void companionStream(String message,
                                List<Map<String, String>> history,
                                Map<String, Object> context,
                                String imageUrl,
                                Long studentId,
                                Long conversationId,
                                SseEmitter emitter) throws Exception {
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
        String json = objectMapper.writeValueAsString(body);
        String url = baseUrl + "/internal/companion/stream";

        // 使用 RestTemplate：底层 SimpleClientHttpRequestFactory 会正确携带请求体与 Content-Length，
        // 避免低层 HttpClient 空 body 导致 AI 中台 400 校验失败（学伴无输出）。
        restTemplate.execute(url, HttpMethod.POST,
                request -> {
                    request.getHeaders().setContentType(MediaType.APPLICATION_JSON);
                    request.getHeaders().set("X-Internal-Token", internalToken);
                    request.getHeaders().set("Cache-Control", "no-cache");
                    request.getBody().write(json.getBytes(StandardCharsets.UTF_8));
                },
                response -> {
                    if (response.getStatusCode().value() != 200) {
                        throw new BizException(ResultCode.AI_SERVICE_ERROR,
                                "AI学伴流式服务异常: HTTP " + response.getStatusCode().value());
                    }
                    // 在回调内读取，流尚未被 RestTemplate 关闭
                    forwardSseToEmitter(response.getBody(), emitter);
                    return null;
                });
    }

    /**
     * 16. AI 教学设计生成（智能备课·助教核心）
     * POST {ai-base-url}/lesson/design
     * 返回教学设计 JSON；AI 不可用时返回 null（非关键能力，优雅降级）。
     */
    @SuppressWarnings("unchecked")
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
        return postData("/lesson/design", body);
    }

    /**
     * 16.1 向导式备课对话（智能备课·助教核心）
     * POST {ai-base-url}/lesson/guide
     * 输入已确认要素 + 用户回答，返回下一个问题/快捷选项/是否完成/需求单。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> lessonGuide(String title, Map<String, Object> confirmed,
                                           String userReply, Integer step) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title == null ? "" : title);
        body.put("confirmed", confirmed == null ? Map.of() : confirmed);
        body.put("userReply", userReply == null ? "" : userReply);
        body.put("step", step == null ? 0 : step);
        return postData("/lesson/guide", body);
    }

    /**
     * 16.2 AI 合并多份教案（智能备课·助教核心）
     * POST {ai-base-url}/lesson/merge
     * 以优先级最高教案为主体，用 LLM 消解多方内容冲突，产出单一连贯教案设计。
     * designs 需按优先级从高到低传入（第 1 份为最高优先级）。
     * AI 不可用或返回异常时返回 null，调用方据此回退到规则合并（优雅降级）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> lessonMerge(String title, String department, String targetGrade,
                                           Integer lessonDuration, List<Map<String, Object>> designs) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title == null ? "" : title);
        body.put("department", department == null ? "" : department);
        body.put("targetGrade", targetGrade == null ? "" : targetGrade);
        body.put("lessonDuration", lessonDuration == null ? 45 : lessonDuration);
        body.put("designs", designs == null ? List.of() : designs);
        return postData("/lesson/merge", body);
    }

    /**
     * 16.3 AI 生成课件素材/PPT 提纲（智能备课·助教核心）
     * POST {ai-base-url}/lesson/ppt
     * 基于已生成的教案设计（ai_design_json）生成分页 PPT 课件提纲；AI 不可用时返回 null。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> lessonPptOutline(String title, String department, String targetGrade,
                                                String designJson, String caseContext, Integer slideCount) {
        Map<String, Object> body = new HashMap<>();
        body.put("title", title == null ? "" : title);
        body.put("department", department == null ? "" : department);
        body.put("targetGrade", targetGrade == null ? "" : targetGrade);
        body.put("designJson", designJson == null ? "" : designJson);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        body.put("slideCount", slideCount == null ? 12 : slideCount);
        return postData("/lesson/ppt", body);
    }

    /**
     * 17. AI 学情预警干预建议（助教：学情诊断）
     * POST {ai-base-url}/insight/alert
     * 基于学生预警数据生成个性化干预建议；AI 不可用时返回 null（优雅降级）。
     */
    @SuppressWarnings("unchecked")
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
        return postData("/insight/alert", body);
    }

    /**
     * 18. AI 主观题（简答/论述）批阅（助教：作业与试题批改）
     * POST {ai-base-url}/review/essay
     * 按教师配置评分要点批阅，返回维度评分与改进建议。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> reviewEssay(String question, String scoringPoints,
                                           String studentAnswer, String caseContext,
                                           List<Map<String, Object>> textbookRefs) {
        Map<String, Object> body = new HashMap<>();
        body.put("question", question == null ? "" : question);
        body.put("scoringPoints", scoringPoints == null ? "" : scoringPoints);
        body.put("studentAnswer", studentAnswer == null ? "" : studentAnswer);
        body.put("caseContext", caseContext == null ? "" : caseContext);
        body.put("textbookRefs", textbookRefs == null ? List.of() : textbookRefs);
        return postData("/review/essay", body);
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
     * 16. 教材知识库向量检索（分科过滤）
     * POST {ai-base-url}/knowledge/search
     * 支持按 subject 学科过滤（内科/心电等），失败返回空列表（优雅降级）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> searchKnowledge(String query, int topK, String subject, String collection, String strategy) {
        Map<String, Object> body = new HashMap<>();
        body.put("query", query);
        body.put("topK", topK);
        if (subject != null && !subject.isBlank()) body.put("subject", subject);
        if (collection != null && !collection.isBlank()) body.put("collection", collection);
        if (strategy != null && !strategy.isBlank()) body.put("strategy", strategy);
        return postData("/knowledge/search", body);
    }

    /**
     * 17. 触发教材向量化入库（管理端）——异步任务，立即返回 ingestionId
     * POST {ai-base-url}/knowledge/ingest
     * 入参 objectKey 为 AI 对象存储根目录（/app/data/objects）内的相对路径（如 ebooks/xxx.pdf）。
     * attemptKey 为本次触发的唯一重试令牌：AI 幂等键含 attemptKey，重试/重新入库传新值即可真正创建新任务。
     * AI 完成入库后会异步回调 /api/internal/knowledge/callback 更新 ingest_status（回调携带 ingestionId）。
     * 失败返回 null（AI 不可用），调用方据此保留 ingest_status 不变并抛 AI_SERVICE_ERROR。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> ingestKnowledge(Long textbookId, String objectKey,
                                               String bookName, String edition, String subject,
                                               String attemptKey) {
        Map<String, Object> body = new HashMap<>();
        body.put("textbookId", textbookId);
        body.put("objectKey", objectKey);
        if (bookName != null && !bookName.isBlank()) body.put("bookName", bookName);
        if (edition != null && !edition.isBlank()) body.put("edition", edition);
        if (subject != null && !subject.isBlank()) body.put("subject", subject);
        if (attemptKey != null && !attemptKey.isBlank()) body.put("attemptKey", attemptKey);
        return postData("/knowledge/ingest", body);
    }

    /**
     * 查询 AI 中台任务详情（GET {ai-base-url}/v1/ai/tasks/{taskId}），返回 data 字段；
     * AI 不可达/任务不存在时返回 null，调用方据此降级为本地持久化信息。
     */
    public Map<String, Object> getAiTaskDetail(String taskId) {
        if (taskId == null || taskId.isBlank()) {
            return null;
        }
        return getData("/v1/ai/tasks/" + taskId);
    }

    /**
     * 15. 错题智能推荐（薄弱知识点 → 个性化补救建议）
     * POST {ai-base-url}/internal/recommend/weakness
     * 传入候选教材 / 候选基础题标题，约束 LLM 只从候选里推荐（防幻觉）。
     * 失败返回 null（优雅降级，不阻断错题板块）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> recommendWeakness(List<String> knowledgeTags,
                                                 List<String> mistakes,
                                                 List<String> candidateTextbooks,
                                                 List<String> candidateQuestions) {
        Map<String, Object> body = new HashMap<>();
        body.put("knowledgeTags", knowledgeTags == null ? List.of() : knowledgeTags);
        body.put("mistakes", mistakes == null ? List.of() : mistakes);
        body.put("candidateTextbooks", candidateTextbooks == null ? List.of() : candidateTextbooks);
        body.put("candidateQuestions", candidateQuestions == null ? List.of() : candidateQuestions);
        return postData("/internal/recommend/weakness", body);
    }

    /**
     * 19. 错题 AI 归因（错题归因 Agent）
     * POST {ai-base-url}/internal/mistake/analyze
     * 输入单条错题（题目 + 学生答案 + 标准答案 + 错误类型），返回
     * rootCause / explanation / recommendedTags / practiceHint / source / status。
     * AI 不可用时 data 为 status=DEGRADED 的降级对象（仍返回 code=0），
     * 调用方据此不落缓存、移动端展示可重试提示。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> analyzeMistake(Long mistakeId, Long studentId, String mistakeType,
                                              String knowledgeTag, String caseTitle, String question,
                                              String studentAnswer, String standardAnswer,
                                              String evidence) {
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
        return postData("/internal/mistake/analyze", body);
    }

    /**
     * 20. 薄弱点学情诊断（学情诊断 Agent）
     * POST {ai-base-url}/internal/diagnosis/weakness
     * 输入统计薄弱点（STAT）+ 近期错题，返回整体诊断 + 逐薄弱点 AI 归因。
     * AI 不可用时 data 为 status=DEGRADED 的降级对象，调用方回退纯统计。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> weaknessDiagnosis(Long studentId,
                                                 List<Map<String, Object>> weaknesses,
                                                 List<Map<String, Object>> mistakes) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        body.put("weaknesses", weaknesses == null ? List.of() : weaknesses);
        body.put("mistakes", mistakes == null ? List.of() : mistakes);
        return postData("/internal/diagnosis/weakness", body);
    }

    /**
     * 21. AI 组卷（组卷 Agent · P2-4 学生自测）
     * POST {ai-base-url}/internal/paper/generate
     * 输入薄弱知识点 + 题库候选（审核通过的真实题目），LLM 从候选中选题组卷，
     * 返回 paperTitle / selectedIds / rationale / source / status。
     * AI 不可用时 data 为 status=DEGRADED 的降级对象，调用方回退规则组卷。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> generatePaper(Long studentId, Integer count, Integer difficulty,
                                             List<String> focusTags,
                                             List<Map<String, Object>> candidates) {
        Map<String, Object> body = new HashMap<>();
        body.put("studentId", studentId);
        body.put("count", count == null ? 10 : count);
        if (difficulty != null) body.put("difficulty", difficulty);
        body.put("focusTags", focusTags == null ? List.of() : focusTags);
        body.put("candidates", candidates == null ? List.of() : candidates);
        return postData("/internal/paper/generate", body);
    }

    /**
     * 22. 以图搜图（影像检索 · P1-4 多模态医学知识库）
     * POST {ai-base-url}/knowledge/search-image
     * 输入医学图片 base64（+可选文本），多模态 embedding 检索教材影像知识库，
     * 返回 data.citations（含 book_name/chapter/page/chunk_text/subject/score/image_key）。
     * AI 不可用时返回 null（优雅降级）。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> searchKnowledgeByImage(String imageBase64, String text,
                                                      Integer topK, String subject) {
        Map<String, Object> body = new HashMap<>();
        body.put("imageBase64", imageBase64);
        if (text != null && !text.isBlank()) body.put("text", text);
        if (topK != null) body.put("topK", topK);
        if (subject != null && !subject.isBlank()) body.put("subject", subject);
        return postData("/knowledge/search-image", body);
    }

    /**
     * 获取教材图片字节（P1-4 影像检索回显原图）
     * GET {ai-base-url}/images/{imageKey}
     * 返回图片二进制；图片不存在/AI 不可用时返回 null。
     */
    public byte[] getKnowledgeImage(String imageKey) {
        String url = baseUrl + "/images/" + imageKey;
        try {
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();
            java.net.http.HttpRequest req = java.net.http.HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("X-Internal-Token", internalToken)
                    .timeout(Duration.ofSeconds(30))
                    .GET()
                    .build();
            HttpResponse<byte[]> resp = client.send(req, HttpResponse.BodyHandlers.ofByteArray());
            if (resp.statusCode() == 200) {
                return resp.body();
            }
            log.warn("获取AI教材图片失败: status={} key={}", resp.statusCode(), imageKey);
            return null;
        } catch (Exception e) {
            log.warn("获取AI教材图片异常: key={} error={}", imageKey, e.getMessage());
            return null;
        }
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
     * 严格的 POST 请求并解析 data 字段：AI 返回错误码或无 data 时，抛出携带其真实
     * message 的 BizException（而非静默返回 null），供调用方/全局异常处理透传给客户端诊断。
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> postDataStrict(String path, Map<String, Object> body) {
        String json = post(path, body); // 网络/HTTP/授权层异常已由 post() 抛 BizException
        try {
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            JsonNode msg = root.get("message");
            String realMsg = msg != null && msg.isTextual() && !msg.asText().isBlank()
                    ? msg.asText() : "AI 返回数据异常";
            log.warn("AI中台返回错误: {} resp={}", path, json);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, realMsg);
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("AI中台响应解析失败，返回异常: {} error={}", path, e.getMessage());
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI服务响应解析异常");
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

            // 安全：body 仅打键名清单（调试用）；具体值降级到 debug，防止未来请求体
            // 携带 apiKey 等敏感字段时在 info 日志中明文泄露。
            if (body != null) {
                log.info("调用AI中台: POST {} bodyKeys={}", url, body.keySet());
                if (log.isDebugEnabled()) {
                    log.debug("调用AI中台: POST {} body={}", url, body);
                }
            } else {
                log.info("调用AI中台: POST {}", url);
            }
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

    // ==================== AI 配置中心 · 运行态 / 基线（GET 代理） ====================

    /**
     * 解析 AI 中台 R 包装响应的 data 字段为 Map；解析失败返回 null（调用方降级）。
     * 用于同步接口需要把 data 透传给移动端结构化对象时。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> parseData(String json) {
        if (json == null || json.isBlank()) {
            return null;
        }
        try {
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            return null;
        } catch (Exception e) {
            log.warn("解析 AI data 失败: {}", e.getMessage());
            return null;
        }
    }

    /**
     * AI 配置中心运行态快照（刷新时间 / 生效来源 / RAG 生效值 / 模型脱敏视图）。
     * AI 中台不可用时返回 null，管理端据此展示「无法连接 AI 中台」。
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getConfigStatus() {
        return getData("/internal/config/status");
    }

    /** 触发 AI 中台全量配置刷新，返回刷新后的版本与错误状态。 */
    public Map<String, Object> refreshConfig() {
        return postData("/internal/config/refresh", null);
    }

    /** AI 中台内置提示词基线（供管理端一键导入数据库再编辑），AI 不可用时返回 null */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getPromptBaseline() {
        return getData("/internal/config/baseline/prompts");
    }

    /** AI 中台内置 Agent 元参数基线，AI 不可用时返回 null */
    @SuppressWarnings("unchecked")
    public Map<String, Object> getAgentBaseline() {
        return getData("/internal/config/baseline/agents");
    }

    /**
     * 统一的内部 GET 请求并解析 data 字段；AI 中台不可用或返回异常时返回 null（不抛异常，优雅降级）。
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> getData(String path) {
        String url = baseUrl + path;
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("X-Internal-Token", internalToken);
            HttpEntity<Void> entity = new HttpEntity<>(headers);
            ResponseEntity<String> resp = restTemplate.exchange(url, HttpMethod.GET, entity, String.class);
            JsonNode root = objectMapper.readTree(resp.getBody());
            if (root.get("code") != null && root.get("code").asInt() != 0) {
                log.warn("AI中台配置接口返回错误: {} resp={}", url, resp.getBody());
                return null;
            }
            JsonNode data = root.get("data");
            if (data != null && data.isObject()) {
                return objectMapper.convertValue(data, Map.class);
            }
            log.warn("AI中台配置接口响应中无data字段: {} resp={}", url, resp.getBody());
            return null;
        } catch (Exception e) {
            log.warn("AI中台配置接口调用失败，返回null: {} error={}", url, e.getMessage());
            return null;
        }
    }
}
