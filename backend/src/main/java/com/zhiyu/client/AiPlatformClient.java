package com.zhiyu.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 中台客户端统一门面（PRD 9.3）。阶段3 Phase A 收敛为 Agent 分组门面后，本类
 * 保留全部原有 public 方法签名（调用方与测试零改动），实际逻辑分发给分组门面：
 *
 * <ul>
 *     <li>{@link ConsultationClient} — 问诊咨询</li>
 *     <li>{@link MentorClient} — 导师</li>
 *     <li>{@link EvaluatorClient} — 评测批阅</li>
 *     <li>{@link CoachClient} — 学习教练</li>
 *     <li>{@link TeacherClient} — 教师助手</li>
 *     <li>{@link LessonClient} — 备课教案</li>
 *     <li>{@link CompanionClient} — 陪伴</li>
 * </ul>
 *
 * 基础设施（教材嵌入 / 影像 / 知识库 / 任务 / 配置中心）保留在本类并直连 {@link AiHttpClient}，
 * 不属于 Agent 分组。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiPlatformClient {

    private final AiHttpClient aiHttpClient;
    private final ConsultationClient consultationClient;
    private final MentorClient mentorClient;
    private final EvaluatorClient evaluatorClient;
    private final CoachClient coachClient;
    private final TeacherClient teacherClient;
    private final LessonClient lessonClient;
    private final CompanionClient companionClient;

    // ==================== 问诊咨询 consultation ====================

    /** 问诊聊天流式转发（SSE）。 */
    public void streamChat(Long sessionId, Long studentId, Long caseId, String message, SseEmitter emitter) {
        consultationClient.streamChat(sessionId, studentId, caseId, message, emitter);
    }

    /** 问诊聊天同步转发。 */
    public Map<String, Object> chatSync(Long sessionId, Long studentId, Long caseId, String message) {
        return consultationClient.chatSync(sessionId, studentId, caseId, message);
    }

    /** SP 开场白：返回 data.reply；AI 不可用返回 null。 */
    public String chatOpening(Long sessionId, Long studentId, Long caseId) {
        return consultationClient.chatOpening(sessionId, studentId, caseId);
    }

    // ==================== 导师 mentor ====================

    /** 导师按需小结：思维树 + 苏格拉底提示。 */
    public Map<String, Object> sessionMentor(Long sessionId, Long studentId, Long caseId) {
        return mentorClient.sessionMentor(sessionId, studentId, caseId);
    }

    // ==================== 评测批阅 evaluator ====================

    /** 大病历批阅。 */
    public String reviewMedicalRecord(Long instanceId, String medicalRecordText) {
        return evaluatorClient.reviewMedicalRecord(instanceId, medicalRecordText);
    }

    /** 每日一例评估。 */
    public String evaluateDailyCase(Long studentId, Long caseId, String answer,
                                    String caseSummary, String keyFindings, String standardAnswer) {
        return evaluatorClient.evaluateDailyCase(
                studentId, caseId, answer, caseSummary, keyFindings, standardAnswer);
    }

    /** 会话评估与归档。 */
    public void evaluateAndArchiveSession(Long sessionId, Long studentId) {
        evaluatorClient.evaluateAndArchiveSession(sessionId, studentId);
    }

    /** 主观题（简答/论述）批阅。 */
    public Map<String, Object> reviewEssay(String question, String scoringPoints,
                                           String studentAnswer, String caseContext,
                                           List<Map<String, Object>> textbookRefs) {
        return evaluatorClient.reviewEssay(question, scoringPoints, studentAnswer, caseContext, textbookRefs);
    }

    /** 每日病历 · 段落教练（三级提示梯度，绝不代写）。 */
    public Map<String, Object> mrSegmentHint(Long scheduleId, Long studentId, String segmentKey,
                                             String segmentName, String segmentSpec, int hintLevel,
                                             String draft, String caseSummary, String keyFindings,
                                             List<String> materials) {
        return evaluatorClient.mrSegmentHint(scheduleId, studentId, segmentKey, segmentName,
                segmentSpec, hintLevel, draft, caseSummary, keyFindings, materials);
    }

    /** 每日病历 · 结构化批阅（九段评分 + 缺陷打标 + 置信度）。 */
    public Map<String, Object> mrReview(Long recordId, Long scheduleId, Long studentId,
                                        Map<String, String> record, String caseContext,
                                        String standardAnswer) {
        return evaluatorClient.mrReview(recordId, scheduleId, studentId, record, caseContext, standardAnswer);
    }

    // ==================== 学习教练 coach ====================

    /** 生成学习路径（学习教练 Agent），失败返回 null（优雅降级）。 */
    public String generateLearningPath(Long studentId, Map<String, Object> facts) {
        return coachClient.generateLearningPath(studentId, facts);
    }

    /** 错题智能推荐，失败返回 null。 */
    public Map<String, Object> recommendWeakness(List<String> knowledgeTags,
                                                 List<String> mistakes,
                                                 List<String> candidateTextbooks,
                                                 List<String> candidateQuestions) {
        return coachClient.recommendWeakness(
                knowledgeTags, mistakes, candidateTextbooks, candidateQuestions);
    }

    /** 错题 AI 归因。 */
    public Map<String, Object> analyzeMistake(Long mistakeId, Long studentId, String mistakeType,
                                              String knowledgeTag, String caseTitle, String question,
                                              String studentAnswer, String standardAnswer,
                                              String evidence) {
        return coachClient.analyzeMistake(
                mistakeId, studentId, mistakeType, knowledgeTag, caseTitle,
                question, studentAnswer, standardAnswer, evidence);
    }

    /** 错题归因（增强）：支持主观题模式与批阅明细。 */
    public Map<String, Object> analyzeMistake(Long mistakeId, Long studentId, String mistakeType,
                                              String knowledgeTag, String caseTitle, String question,
                                              String studentAnswer, String standardAnswer,
                                              String evidence, String questionType, Double score,
                                              List<Map<String, Object>> essayMistakes) {
        return coachClient.analyzeMistake(
                mistakeId, studentId, mistakeType, knowledgeTag, caseTitle,
                question, studentAnswer, standardAnswer, evidence, questionType, score, essayMistakes);
    }

    /** 薄弱点学情诊断。 */
    public Map<String, Object> weaknessDiagnosis(Long studentId,
                                                 List<Map<String, Object>> weaknesses,
                                                 List<Map<String, Object>> mistakes) {
        return coachClient.weaknessDiagnosis(studentId, weaknesses, mistakes);
    }

    /** AI 组卷。 */
    public Map<String, Object> generatePaper(Long studentId, Integer count, Integer difficulty,
                                             List<String> focusTags,
                                             List<Map<String, Object>> candidates) {
        return coachClient.generatePaper(studentId, count, difficulty, focusTags, candidates);
    }

    /** 学情预警干预建议。 */
    public Map<String, Object> alertIntervention(String studentName,
                                                 List<Map<String, Object>> riskRules,
                                                 List<Map<String, Object>> weaknesses,
                                                 List<Map<String, Object>> recentMistakes,
                                                 List<Map<String, Object>> recommendedCases,
                                                 List<Map<String, Object>> textbookRefs) {
        return coachClient.alertIntervention(
                studentName, riskRules, weaknesses, recentMistakes, recommendedCases, textbookRefs);
    }

    // ==================== 教师助手 teacher ====================

    /** AI 生成 SP 病例草稿（strict，透传真实错误）。 */
    public Map<String, Object> generateCaseDraft(String chiefComplaint, String department,
                                                 Integer difficulty, List<String> teachingGoals,
                                                 String remark) {
        return teacherClient.generateCaseDraft(
                chiefComplaint, department, difficulty, teachingGoals, remark);
    }

    /** AI 班级学情洞察。 */
    public Map<String, Object> classInsight(String className, List<Map<String, Object>> stats,
                                            Map<String, Integer> osceDimensionScores,
                                            List<Map<String, Object>> commonMistakes) {
        return teacherClient.classInsight(className, stats, osceDimensionScores, commonMistakes);
    }

    /** AI 复核辅助。 */
    public Map<String, Object> reviewAssist(Long instanceId, String medicalRecordText,
                                            Double aiScore, List<Map<String, Object>> aiMistakes,
                                            String caseContext) {
        return teacherClient.reviewAssist(instanceId, medicalRecordText, aiScore, aiMistakes, caseContext);
    }

    /** AI 推荐作业病例。 */
    public Map<String, Object> recommendCases(Long classId, List<Map<String, Object>> weaknesses,
                                              List<Map<String, Object>> candidateCases) {
        return teacherClient.recommendCases(classId, weaknesses, candidateCases);
    }

    /** AI 病例质检。 */
    public Map<String, Object> qualityCheck(Long caseId, String title, String hiddenDisease,
                                            List<String> standardPath, List<Map<String, Object>> presetExams,
                                            List<String> knowledgeTags) {
        return teacherClient.qualityCheck(
                caseId, title, hiddenDisease, standardPath, presetExams, knowledgeTags);
    }

    /** 病例素材智能推荐（多模态材料清单建议）。 */
    public Map<String, Object> materialAdvice(Long caseId, String title, String department,
                                              String complaint, String hiddenDisease,
                                              String presentIllness, List<String> existingExams) {
        return teacherClient.materialAdvice(
                caseId, title, department, complaint, hiddenDisease, presentIllness, existingExams);
    }

    /** AI 自动生成练习题。 */
    public Map<String, Object> practiceQuestions(Long caseId, String hiddenDisease,
                                                 List<String> standardPath, List<String> knowledgeTags) {
        return teacherClient.practiceQuestions(caseId, hiddenDisease, standardPath, knowledgeTags);
    }

    /** AI 教学设计生成。 */
    public Map<String, Object> lessonDesign(String title, String department, String targetGrade,
                                            List<String> teachingGoals, String caseContext,
                                            List<Map<String, Object>> textbookRefs,
                                            String studentProfile, Integer lessonDuration,
                                            List<Map<String, Object>> materialRefs) {
        return lessonClient.lessonDesign(
                title, department, targetGrade, teachingGoals, caseContext,
                textbookRefs, studentProfile, lessonDuration, materialRefs);
    }

    /** 向导式备课对话。 */
    public Map<String, Object> lessonGuide(String title, Map<String, Object> confirmed,
                                           String userReply, Integer step) {
        return lessonClient.lessonGuide(title, confirmed, userReply, step);
    }

    /** AI 合并多份教案。 */
    public Map<String, Object> lessonMerge(String title, String department, String targetGrade,
                                           Integer lessonDuration, List<Map<String, Object>> designs) {
        return lessonClient.lessonMerge(title, department, targetGrade, lessonDuration, designs);
    }

    /** AI 生成课件素材/PPT 提纲。 */
    public Map<String, Object> lessonPptOutline(String title, String department, String targetGrade,
                                                String designJson, String caseContext, Integer slideCount) {
        return lessonClient.lessonPptOutline(
                title, department, targetGrade, designJson, caseContext, slideCount);
    }

    // ==================== 陪伴 companion ====================

    /** AI 学伴 · 同步。 */
    public Map<String, Object> companionSync(String message,
                                             List<Map<String, String>> history,
                                             Map<String, Object> context,
                                             String imageUrl,
                                             Long studentId,
                                             Long conversationId) {
        return companionClient.companionSync(
                message, history, context, imageUrl, studentId, conversationId);
    }

    /** AI 学伴 · 流式（SSE）。 */
    public void companionStream(String message,
                                List<Map<String, String>> history,
                                Map<String, Object> context,
                                String imageUrl,
                                Long studentId,
                                Long conversationId,
                                SseEmitter emitter) throws Exception {
        companionClient.companionStream(
                message, history, context, imageUrl, studentId, conversationId, emitter);
    }

    // ==================== 基础设施（非 Agent 分组） ====================

    /** 教材向量化嵌入。 */
    public String embedTextbook(Long textbookId, String fileUrl) {
        Map<String, Object> body = new HashMap<>();
        body.put("textbookId", textbookId);
        body.put("fileUrl", fileUrl);
        return aiHttpClient.post("/embed/textbook", body);
    }

    /** 影像 AI 读图分析（移动端学生 JWT 鉴权）。 */
    public Map<String, Object> analyzeVision(Long sessionId, Long studentId, String imageUrl,
                                             List<Double> imageBbox, String studentNote,
                                             String mobileToken) {
        Map<String, Object> body = new HashMap<>();
        body.put("session_id", sessionId);
        body.put("image_url", imageUrl);
        if (imageBbox != null && !imageBbox.isEmpty()) body.put("image_bbox", imageBbox);
        if (studentNote != null && !studentNote.isBlank()) body.put("student_note", studentNote);
        return aiHttpClient.postDataWithBearer("/v1/ai/vision/analyze", body, mobileToken);
    }

    /** 教材知识库向量检索（分科过滤），失败返回空列表（优雅降级）。 */
    public Map<String, Object> searchKnowledge(String query, int topK, String subject, String collection, String strategy) {
        Map<String, Object> body = new HashMap<>();
        body.put("query", query);
        body.put("topK", topK);
        if (subject != null && !subject.isBlank()) body.put("subject", subject);
        if (collection != null && !collection.isBlank()) body.put("collection", collection);
        if (strategy != null && !strategy.isBlank()) body.put("strategy", strategy);
        return aiHttpClient.postData("/knowledge/search", body);
    }

    /** 触发教材向量化入库（管理端，异步任务），失败返回 null。 */
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
        return aiHttpClient.postData("/knowledge/ingest", body);
    }

    /** 查询 AI 中台任务详情，AI 不可达/不存在返回 null。 */
    public Map<String, Object> getAiTaskDetail(String taskId) {
        if (taskId == null || taskId.isBlank()) {
            return null;
        }
        return aiHttpClient.getData("/v1/ai/tasks/" + taskId);
    }

    /** 以图搜图（影像检索）。 */
    public Map<String, Object> searchKnowledgeByImage(String imageBase64, String text,
                                                      Integer topK, String subject) {
        Map<String, Object> body = new HashMap<>();
        body.put("imageBase64", imageBase64);
        if (text != null && !text.isBlank()) body.put("text", text);
        if (topK != null) body.put("topK", topK);
        if (subject != null && !subject.isBlank()) body.put("subject", subject);
        return aiHttpClient.postData("/knowledge/search-image", body);
    }

    /** 获取教材图片字节；图片不存在/AI 不可用返回 null。 */
    public byte[] getKnowledgeImage(String imageKey) {
        java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                .connectTimeout(java.time.Duration.ofSeconds(10))
                .build();
        java.net.http.HttpRequest req = java.net.http.HttpRequest.newBuilder()
                .uri(java.net.URI.create(aiHttpClient.getBaseUrl() + "/images/" + imageKey))
                .header("X-Internal-Token", aiHttpClient.getInternalToken())
                .timeout(java.time.Duration.ofSeconds(30))
                .GET()
                .build();
        try {
            java.net.http.HttpResponse<byte[]> resp = client.send(
                    req, java.net.http.HttpResponse.BodyHandlers.ofByteArray());
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

    // ==================== AI 配置中心（基础设施，非 Agent 分组） ====================

    /** 解析 AI 中台 R 包装响应的 data 字段。 */
    public Map<String, Object> parseData(String json) {
        return aiHttpClient.parseData(json);
    }

    /** AI 配置中心运行态快照。 */
    public Map<String, Object> getConfigStatus() {
        return aiHttpClient.getData("/internal/config/status");
    }

    /** 触发 AI 中台全量配置刷新。 */
    public Map<String, Object> refreshConfig() {
        return aiHttpClient.postData("/internal/config/refresh", null);
    }

    /** AI 中台内置提示词基线。 */
    public Map<String, Object> getPromptBaseline() {
        return aiHttpClient.getData("/internal/config/baseline/prompts");
    }

    /** AI 中台内置 Agent 元参数基线。 */
    public Map<String, Object> getAgentBaseline() {
        return aiHttpClient.getData("/internal/config/baseline/agents");
    }
}

    