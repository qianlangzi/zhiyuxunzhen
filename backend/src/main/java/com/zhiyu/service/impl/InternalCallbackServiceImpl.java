package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentItemProgress;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.ModelEventLog;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.ModelEventLogMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.InternalCallbackService;
import com.zhiyu.service.WeaknessAnalysisService;
import com.zhiyu.service.dto.internal.KnowledgeCallbackDTO;
import com.zhiyu.service.dto.internal.MistakesSyncDTO;
import com.zhiyu.service.dto.internal.ModelEventLogDTO;
import com.zhiyu.service.dto.internal.ReviewCallbackDTO;
import com.zhiyu.service.dto.internal.SessionArchiveDTO;
import com.zhiyu.service.dto.internal.WeaknessSyncDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.CollectionUtils;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 内部回调服务实现（PRD 9.4）
 * 接收 FastAPI 中台的异步回调，更新业务数据
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class InternalCallbackServiceImpl implements InternalCallbackService {

    private final ChatSessionMapper chatSessionMapper;
    private final MedicalRecordReviewMapper medicalRecordReviewMapper;
    private final AssignmentInstanceMapper assignmentInstanceMapper;
    private final AssignmentItemProgressMapper assignmentItemProgressMapper;
    private final StudentMistakesMapper studentMistakesMapper;
    private final StudentWeaknessMapper studentWeaknessMapper;
    private final TextbookMapper textbookMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;
    private final WeaknessAnalysisService weaknessAnalysisService;
    private final ModelEventLogMapper modelEventLogMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void archiveSession(SessionArchiveDTO dto) {
        if (dto.getSessionId() == null) {
            throw new BizException(ResultCode.BAD_REQUEST, "sessionId 不能为空");
        }

        ChatSession session = chatSessionMapper.selectById(dto.getSessionId());
        if (session == null) {
            throw new BizException(ResultCode.NOT_FOUND, "问诊会话不存在: " + dto.getSessionId());
        }

        session.setStatus(1); // 已完成
        session.setOsceScoreJson(dto.getOsceScoreJson());
        session.setFinalReport(dto.getFinalReport());
        session.setReasoningTreeJson(dto.getReasoningTreeJson());
        session.setEndedAt(LocalDateTime.now());
        chatSessionMapper.updateById(session);

        log.info("问诊会话归档完成: sessionId={}", dto.getSessionId());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void reviewCallback(ReviewCallbackDTO dto) {
        if (dto.getInstanceId() == null) {
            throw new BizException(ResultCode.BAD_REQUEST, "instanceId 不能为空");
        }

        // 组合包场景:AI 中台回传的 instanceId 实为任务项进度ID(progress_id),优先按进度定位
        AssignmentItemProgress progress = assignmentItemProgressMapper.selectById(dto.getInstanceId());
        if (progress != null) {
            // 创建 AI 批阅记录(挂任务项进度)
            MedicalRecordReview review = new MedicalRecordReview();
            review.setInstanceId(progress.getInstanceId());
            review.setAssignmentItemProgressId(progress.getId());
            review.setReviewerType("AI");
            review.setTotalScore(dto.getTotalScore());
            review.setMistakesJson(dto.getMistakesJson());
            review.setReviewComment(dto.getReviewComment());
            medicalRecordReviewMapper.insert(review);

            // 任务项进度 -> 待复核(4),记录 AI 评分
            progress.setStatus(4);
            progress.setScore(dto.getTotalScore());
            progress.setAiErrorMessage(null);
            progress.setAiRetryCount(0);
            progress.setAiLastAttemptAt(null);
            assignmentItemProgressMapper.updateById(progress);

            // 作业实例聚合状态同步
            refreshInstanceStatus(progress.getInstanceId());
            log.info("AI批阅结果写入完成(任务项): progressId={}, reviewId={}, score={}",
                    progress.getId(), review.getId(), dto.getTotalScore());
            return;
        }

        // 存量场景:按作业实例处理
        AssignmentInstance instance = assignmentInstanceMapper.selectById(dto.getInstanceId());
        if (instance == null) {
            log.warn("AI批阅回调: 作业实例不存在 instanceId={}", dto.getInstanceId());
            return;
        }
        MedicalRecordReview review = new MedicalRecordReview();
        review.setInstanceId(dto.getInstanceId());
        review.setReviewerType("AI");
        review.setTotalScore(dto.getTotalScore());
        review.setMistakesJson(dto.getMistakesJson());
        review.setReviewComment(dto.getReviewComment());
        medicalRecordReviewMapper.insert(review);

        instance.setStatus(4);
        assignmentInstanceMapper.updateById(instance);

        log.info("AI批阅结果写入完成: instanceId={}, reviewId={}, score={}",
                dto.getInstanceId(), review.getId(), dto.getTotalScore());
    }

    /** 聚合刷新作业实例状态:全部任务项完成=5,否则有进行中=1,全未开始=0 */
    private void refreshInstanceStatus(Long instanceId) {
        AssignmentInstance instance = assignmentInstanceMapper.selectById(instanceId);
        if (instance == null) return;
        List<AssignmentItemProgress> ps = assignmentItemProgressMapper.selectList(
                new LambdaQueryWrapper<AssignmentItemProgress>()
                        .eq(AssignmentItemProgress::getInstanceId, instanceId));
        if (ps.isEmpty()) return;
        boolean allDone = ps.stream().allMatch(p -> p.getStatus() != null && p.getStatus() == 5);
        boolean anyActive = ps.stream().anyMatch(p -> p.getStatus() != null && p.getStatus() > 0);
        if (allDone) {
            instance.setStatus(5);
        } else if (anyActive) {
            instance.setStatus(1);
        } else {
            instance.setStatus(0);
        }
        // 总分 = 各任务项得分(0-100)平均
        List<java.math.BigDecimal> scores = ps.stream()
                .map(p -> p.getScore()).filter(java.util.Objects::nonNull).toList();
        if (!scores.isEmpty()) {
            double avg = scores.stream().mapToDouble(java.math.BigDecimal::doubleValue).average().orElse(0);
            instance.setScore(java.math.BigDecimal.valueOf(Math.round(avg * 10) / 10.0));
        }
        assignmentInstanceMapper.updateById(instance);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void syncMistakes(MistakesSyncDTO dto) {
        if (dto == null || CollectionUtils.isEmpty(dto.getMistakes())) {
            log.info("错题同步: 无数据");
            return;
        }

        int count = 0;
        Set<Long> affectedStudents = new HashSet<>();
        for (MistakesSyncDTO.MistakeItem item : dto.getMistakes()) {
            StudentMistakes mistake = new StudentMistakes();
            mistake.setStudentId(item.getStudentId());
            mistake.setSessionId(item.getSessionId());
            mistake.setCaseId(item.getCaseId());
            mistake.setMistakeType(item.getMistakeType());
            mistake.setKnowledgeTag(item.getKnowledgeTag());
            mistake.setStudentAnswer(item.getStudentAnswer());
            mistake.setStandardAnswer(item.getStandardAnswer());
            mistake.setEvidenceJson(item.getEvidenceJson());
            mistake.setResolvedStatus(0); // 未复习
            studentMistakesMapper.insert(mistake);
            if (item.getStudentId() != null) {
                affectedStudents.add(item.getStudentId());
            }
            count++;
        }

        // 错题入库后立即重算相关学生的薄弱知识点掌握度（薄弱度推算闭环）
        for (Long studentId : affectedStudents) {
            weaknessAnalysisService.refreshForStudent(studentId);
        }

        log.info("错题本同步完成: 共 {} 条", count);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void syncWeakness(WeaknessSyncDTO dto) {
        if (dto == null || CollectionUtils.isEmpty(dto.getWeaknessList())) {
            log.info("薄弱知识点同步: 无数据");
            return;
        }

        int count = 0;
        for (WeaknessSyncDTO.WeaknessItem item : dto.getWeaknessList()) {
            // upsert: 按 studentId + knowledgeTag 查找
            StudentWeakness existing = studentWeaknessMapper.selectOne(
                    new LambdaQueryWrapper<StudentWeakness>()
                            .eq(StudentWeakness::getStudentId, item.getStudentId())
                            .eq(StudentWeakness::getKnowledgeTag, item.getKnowledgeTag()));

            if (existing != null) {
                existing.setWeaknessScore(item.getWeaknessScore());
                existing.setEvidenceCount(item.getEvidenceCount());
                existing.setRecommendedPathJson(item.getRecommendedPathJson());
                existing.setLastUpdated(LocalDateTime.now());
                studentWeaknessMapper.updateById(existing);
            } else {
                StudentWeakness weakness = new StudentWeakness();
                weakness.setStudentId(item.getStudentId());
                weakness.setKnowledgeTag(item.getKnowledgeTag());
                weakness.setWeaknessScore(item.getWeaknessScore());
                weakness.setEvidenceCount(item.getEvidenceCount());
                weakness.setRecommendedPathJson(item.getRecommendedPathJson());
                weakness.setLastUpdated(LocalDateTime.now());
                studentWeaknessMapper.insert(weakness);
            }
            count++;
        }

        log.info("薄弱知识点同步完成: 共 {} 条", count);
    }

    @Override
    public void logModelEvent(ModelEventLogDTO dto) {
        String eventType = dto.getEventType() != null ? dto.getEventType() : "unknown";
        String modelName = dto.getModelName() != null ? dto.getModelName() : "";
        String capability = dto.getCapability() != null ? dto.getCapability() : "";
        log.warn("模型事件: type={}, model={}, capability={}, error={}, detail={}, traceId={}",
                eventType, modelName, capability, dto.getErrorMessage(), dto.getDetailJson(), dto.getTraceId());

        // 结构化事件表（管理端「最近模型事件」数据源）：持久化 trace_id / detail_json /
        // capability / recovered 等可查询字段。字段统一截断防超长；detailJson 先序列化后再落库。
        ModelEventLog eventLog = new ModelEventLog();
        eventLog.setEventType(truncate(eventType, 32));
        eventLog.setModelName(truncate(modelName, 64));
        eventLog.setCapability(truncate(capability, 32));
        eventLog.setErrorMessage(truncate(dto.getErrorMessage(), 1000));
        eventLog.setDetailJson(truncate(dto.getDetailJson(), 20000));
        eventLog.setTraceId(truncate(dto.getTraceId(), 64));
        eventLog.setRecovered(Boolean.TRUE.equals(dto.getRecovered()));
        eventLog.setCreatedAt(LocalDateTime.now());
        try {
            modelEventLogMapper.insert(eventLog);
        } catch (Exception e) {
            // 事件记录失败不应阻断 AI 回调主流程；保持原有审计降级约定（记录到日志即可）
            log.error("模型事件结构化落库失败，eventType={}", eventType, e);
        }

        // 记录审计日志，便于管理端追踪
        // M2 修复：String.format 拼接 JSON 在 errorMessage 含引号/反斜杠/换行时产生非法 JSON，
        // 写入 MySQL JSON 列失败 → P1-5 后审计异常传播 → 事务回滚 → 事件丢失。
        // 改用 ObjectMapper 序列化 Map，自动转义特殊字符。
        Map<String, Object> afterMap = new HashMap<>();
        afterMap.put("eventType", eventType);
        afterMap.put("modelName", modelName);
        afterMap.put("capability", capability);
        afterMap.put("errorMessage", dto.getErrorMessage() != null ? dto.getErrorMessage() : "");
        if (dto.getTraceId() != null) {
            afterMap.put("traceId", dto.getTraceId());
        }
        afterMap.put("recovered", Boolean.TRUE.equals(dto.getRecovered()));
        auditLogService.record("model_event_" + eventType,
                "model", null, null, safeJson(afterMap));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void knowledgeCallback(KnowledgeCallbackDTO dto) {
        Long textbookId = dto.getTextbookId();
        if (textbookId == null) {
            throw new BizException(ResultCode.BAD_REQUEST, "textbookId 不能为空");
        }
        Textbook tb = textbookMapper.selectById(textbookId);
        if (tb == null) {
            log.warn("教材入库回调：教材不存在 textbookId={}", textbookId);
            return; // 回调容错：教材已被删除时不抛错
        }

        // 乱序防护：回调携带 ingestionId 且与 textbook 记录的最近任务不一致 → 旧任务迟到回调，丢弃
        String dtoIngestionId = dto.getIngestionId();
        if (StringUtils.hasText(tb.getIngestionId()) && !StringUtils.hasText(dtoIngestionId)) {
            log.warn("教材入库回调丢弃（缺少 ingestionId，无法确认是否为当前任务）: textbookId={} latest={} status={}",
                    textbookId, tb.getIngestionId(), dto.getStatus());
            return;
        }
        if (StringUtils.hasText(dtoIngestionId) && StringUtils.hasText(tb.getIngestionId())
                && !dtoIngestionId.equals(tb.getIngestionId())) {
            log.warn("教材入库回调丢弃（旧任务迟到，ingestionId 不匹配）: textbookId={} dto={} latest={} status={}",
                    textbookId, dtoIngestionId, tb.getIngestionId(), dto.getStatus());
            return;
        }

        String beforeJson = safeJson(Map.of("ingestStatus", tb.getIngestStatus()));
        tb.setIngestStatus(dto.getStatus());
        tb.setIngestError(dto.getStatus() == 3 && dto.getError() != null
                ? truncate(dto.getError(), 500)
                : null);
        tb.setLastIngestAt(LocalDateTime.now());
        // 记录任务 ID：成功/失败均保留最近一次任务，便于管理端按 ingestionId 查询 AI 任务详情
        if (StringUtils.hasText(dtoIngestionId)) {
            tb.setIngestionId(dtoIngestionId);
        }
        textbookMapper.updateById(tb);

        Map<String, Object> after = new HashMap<>();
        after.put("ingestStatus", dto.getStatus());
        if (dto.getError() != null) {
            after.put("error", truncate(dto.getError(), 500));
        }
        if (StringUtils.hasText(dtoIngestionId)) {
            after.put("ingestionId", dtoIngestionId);
        }
        auditLogService.record("textbook_ingest_" + (dto.getStatus() == 2 ? "success" : "failed"),
                "textbook", textbookId, beforeJson, safeJson(after));
        log.info("教材入库回调：textbookId={} status={} ingestionId={} error={}",
                textbookId, dto.getStatus(), dtoIngestionId, truncate(dto.getError(), 300));
    }

    /** 截断为前 max 字符（数据库列宽保护） */
    private String truncate(String s, int max) {
        if (s == null) return null;
        return s.length() <= max ? s : s.substring(0, max);
    }

    /** 用 ObjectMapper 安全序列化为 JSON 字符串（错误信息含引号/换行/反斜杠时避免生成非法 JSON 导致审计失败回滚） */
    private String safeJson(Map<String, Object> map) {
        try {
            return objectMapper.writeValueAsString(map);
        } catch (Exception e) {
            log.error("审计 JSON 序列化失败，降级为空 JSON", e);
            return "{}";
        }
    }
}
