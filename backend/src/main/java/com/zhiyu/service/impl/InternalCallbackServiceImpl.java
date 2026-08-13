package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.InternalCallbackService;
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

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

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
    private final StudentMistakesMapper studentMistakesMapper;
    private final StudentWeaknessMapper studentWeaknessMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

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

        // 创建 AI 批阅记录
        MedicalRecordReview review = new MedicalRecordReview();
        review.setInstanceId(dto.getInstanceId());
        review.setReviewerType("AI");
        review.setTotalScore(dto.getTotalScore());
        review.setMistakesJson(dto.getMistakesJson());
        review.setReviewComment(dto.getReviewComment());
        medicalRecordReviewMapper.insert(review);

        // 更新作业实例状态为待复核(4)
        AssignmentInstance instance = assignmentInstanceMapper.selectById(dto.getInstanceId());
        if (instance != null) {
            instance.setStatus(4);
            assignmentInstanceMapper.updateById(instance);
        } else {
            log.warn("AI批阅回调: 作业实例不存在 instanceId={}", dto.getInstanceId());
        }

        log.info("AI批阅结果写入完成: instanceId={}, reviewId={}, score={}",
                dto.getInstanceId(), review.getId(), dto.getTotalScore());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void syncMistakes(MistakesSyncDTO dto) {
        if (dto == null || CollectionUtils.isEmpty(dto.getMistakes())) {
            log.info("错题同步: 无数据");
            return;
        }

        int count = 0;
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
            count++;
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
        log.warn("模型事件: type={}, model={}, error={}, detail={}",
                dto.getEventType(), dto.getModelName(), dto.getErrorMessage(), dto.getDetailJson());

        // 记录审计日志，便于管理端追踪
        // M2 修复：String.format 拼接 JSON 在 errorMessage 含引号/反斜杠/换行时产生非法 JSON，
        // 写入 MySQL JSON 列失败 → P1-5 后审计异常传播 → 事务回滚 → 事件丢失。
        // 改用 ObjectMapper 序列化 Map，自动转义特殊字符。
        Map<String, Object> afterMap = new HashMap<>();
        afterMap.put("eventType", dto.getEventType());
        afterMap.put("modelName", dto.getModelName() != null ? dto.getModelName() : "");
        afterMap.put("errorMessage", dto.getErrorMessage() != null ? dto.getErrorMessage() : "");
        String afterJson;
        try {
            afterJson = objectMapper.writeValueAsString(afterMap);
        } catch (Exception e) {
            afterJson = "{}";
        }
        auditLogService.record("model_event_" + (dto.getEventType() != null ? dto.getEventType() : "unknown"),
                "model", null, null, afterJson);
    }
}
