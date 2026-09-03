package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.AuditLog;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.SysConfig;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AuditLogMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.dto.RejectDTO;
import com.zhiyu.service.dto.SysConfigUpdateDTO;
import com.zhiyu.service.dto.CreateAuditorDTO;
import com.zhiyu.vo.AdminUserStatsVO;
import com.zhiyu.vo.AdminUserVO;
import com.zhiyu.vo.AuditLogVO;
import com.zhiyu.vo.CaseAuditDetailVO;
import com.zhiyu.vo.CaseAuditVO;
import com.zhiyu.vo.DashboardVO;
import com.zhiyu.vo.QuestionAuditVO;
import com.zhiyu.vo.TeacherAuditDetailVO;
import com.zhiyu.vo.TeacherAuditVO;
import com.zhiyu.vo.SysConfigVO;
import com.zhiyu.vo.TeacherQuestionVO;
import com.zhiyu.vo.TextbookAdminVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 管理端服务实现（PRD 4.13 ~ 4.17）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminServiceImpl implements AdminService {

    private final SysUserMapper userMapper;
    private final SpCaseConfigMapper caseConfigMapper;
    private final PracticeQuestionMapper questionMapper;
    private final TextbookMapper textbookMapper;
    private final AiPlatformClient aiPlatformClient;
    private final ChatSessionMapper chatSessionMapper;
    private final AssignmentInstanceMapper assignmentInstanceMapper;
    private final SysConfigMapper sysConfigMapper;
    private final AuditLogMapper auditLogMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;
    private final PasswordEncoder passwordEncoder;

    /** 默认演示密码，与 ProdSecurityInitializer.DEMO_PASSWORD 保持一致 */
    private static final String DEMO_PASSWORD = "123456";

    /** 临时密码随机源（重置密码用，无安全敏感序列要求，SecureRandom 在此场景非必需） */
    private static final java.util.Random RANDOM = new java.util.Random();

    // ==================== 驾驶舱（PRD 4.13） ====================

    @Override
    public DashboardVO dashboard() {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();

        // 今日活跃学生数：role=0 且今日有登录
        Long todayActiveStudents = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 0)
                        .ge(SysUser::getLastLoginAt, todayStart));

        // 活跃教师数：role=1 且已认证
        Long activeTeachers = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 1)
                        .eq(SysUser::getAuditStatus, 2));

        // 问诊会话总数
        Long chatSessionCount = chatSessionMapper.selectCount(null);

        // 作业提交数：submit_time 不为空
        Long assignmentSubmitCount = assignmentInstanceMapper.selectCount(
                new LambdaQueryWrapper<com.zhiyu.entity.AssignmentInstance>()
                        .isNotNull(com.zhiyu.entity.AssignmentInstance::getSubmitTime));

        // 待审核病例数：is_public=true 且 admin_audit_status=1
        Long pendingCaseAuditCount = caseConfigMapper.selectCount(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getIsPublic, true)
                        .eq(SpCaseConfig::getAdminAuditStatus, 1));

        // 待审核教师数：role=1 且 audit_status IN (1,3)
        Long pendingTeacherAuditCount = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 1)
                        .in(SysUser::getAuditStatus, 1, 3));

        // 官方认证病例数：admin_audit_status=2
        Long officialCaseCount = caseConfigMapper.selectCount(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getAdminAuditStatus, 2));

        return DashboardVO.builder()
                .todayActiveStudents(todayActiveStudents)
                .activeTeachers(activeTeachers)
                .chatSessionCount(chatSessionCount)
                .assignmentSubmitCount(assignmentSubmitCount)
                .pendingCaseAuditCount(pendingCaseAuditCount)
                .pendingTeacherAuditCount(pendingTeacherAuditCount)
                .officialCaseCount(officialCaseCount)
                .build();
    }

    // ==================== 教师资质审核（PRD 4.14） ====================

    @Override
    public PageResult<TeacherAuditVO> teacherAuditList(PageParam param, Integer auditStatus) {
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<SysUser>()
                .eq(SysUser::getRole, 1);
        if (auditStatus != null) {
            // 前端按「待审核(1)/已通过(2)/已驳回(3)」分类筛选
            wrapper.eq(SysUser::getAuditStatus, auditStatus);
        }
        wrapper.orderByDesc(SysUser::getCreatedAt);

        Page<SysUser> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<SysUser> result = userMapper.selectPage(page, wrapper);

        List<TeacherAuditVO> voList = result.getRecords().stream()
                .map(this::toTeacherAuditVO)
                .collect(Collectors.toList());

        return PageResult.of(result, voList);
    }

    @Override
    public TeacherAuditDetailVO teacherAuditDetail(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        return TeacherAuditDetailVO.builder()
                .userId(user.getId())
                .username(user.getUsername())
                .realName(user.getRealName())
                .phone(user.getPhone())
                .idCard(user.getIdCard())
                .department(user.getDepartment())
                .schoolName(user.getSchoolName())
                .grade(user.getGrade())
                .className(user.getClassName())
                .teacherCertificateNo(user.getTeacherCertificateNo())
                .teacherCertificateImage(user.getTeacherCertificateImage())
                .avatar(user.getAvatar())
                .status(user.getStatus())
                .auditStatus(user.getAuditStatus())
                .createdAt(user.getCreatedAt())
                .lastLoginAt(user.getLastLoginAt())
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void approveTeacher(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() == null || user.getRole() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "该用户不是教师");
        }

        String beforeJson = toJson(Map.of("auditStatus", user.getAuditStatus()));

        // P1：审核通过时递增 credential_version，撤销携带旧 auditStatus 的 access token。
        // PermissionInterceptor 依赖 auditStatus=2 才允许教师写操作，旧 token 中的
        // auditStatus=1（待审核）会让教师无法写操作；但若攻击者在审核通过前拿到 token，
        // 审核通过后旧 token 仍带 auditStatus=1，需递增版本强制重新登录拿 auditStatus=2 的新 token。
        //
        // P1-1 修复：CAS 条件增加 .eq("audit_status", 1)，仅待审核状态才可审核通过。
        // 防止迟到 approve 覆盖较新的 reject（管理员先驳回再批准，但迟到的批准请求
        // 在驳回之后执行，把已驳回的账号又变成通过）。
        //
        // H3 修复：CAS 增加 .eq("credential_version", user.getCredentialVersion()) 消除 ABA。
        // 旧 CAS 仅匹配 audit_status=1 → ABA：待审(1)→驳回(3,cv+1)→教师重提交(1)→旧 approve 恢复，
        // 旧请求批准了未经审核的新材料。加入 cv 条件后，驳回递增了 cv，旧 approve 持有的旧 cv 不匹配。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("audit_status", 1)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("audit_status", 2)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "教师不在待审核状态，无法审核通过");
        }

        String afterJson = toJson(Map.of("auditStatus", 2));

        auditLogService.record("teacher_audit_approve", "user", userId, beforeJson, afterJson);
        log.info("教师资质审核通过: userId={}", userId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void rejectTeacher(Long userId, RejectDTO dto) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() == null || user.getRole() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "该用户不是教师");
        }

        String beforeJson = toJson(Map.of("auditStatus", user.getAuditStatus()));

        // P1：审核驳回时递增 credential_version，撤销旧 token，强制教师重新登录拿 auditStatus=3 的新 token。
        // 驳回后旧 token 的 auditStatus=1（待审核）仍能尝试写操作，递增版本后旧 token 被立即拒绝。
        //
        // P1-1 修复：CAS 条件增加 .eq("audit_status", 1)，仅待审核状态才可驳回。
        // 防止迟到 reject 覆盖较新的 approve（管理员先批准再驳回，但迟到的驳回请求
        // 在批准之后执行，把已通过的账号又变成驳回）。
        //
        // H3 修复：CAS 增加 .eq("credential_version", user.getCredentialVersion()) 消除 ABA。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("audit_status", 1)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("audit_status", 3)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "教师不在待审核状态，无法驳回");
        }

        Map<String, Object> afterMap = new HashMap<>();
        afterMap.put("auditStatus", 3);
        afterMap.put("reason", dto.getReason());
        String afterJson = toJson(afterMap);

        auditLogService.record("teacher_audit_reject", "user", userId, beforeJson, afterJson);
        log.info("教师资质审核驳回: userId={}, reason={}", userId, dto.getReason());
    }

    // ==================== 病例审核（PRD 4.15） ====================

    @Override
    public PageResult<CaseAuditVO> caseAuditList(PageParam param, Integer auditStatus) {
        LambdaQueryWrapper<SpCaseConfig> wrapper = new LambdaQueryWrapper<SpCaseConfig>()
                .eq(SpCaseConfig::getIsPublic, true)
                .orderByDesc(SpCaseConfig::getCreatedAt);
        if (auditStatus != null) {
            // 前端按「待审核(1)/已通过(2)/已驳回(3)」分类筛选
            wrapper.eq(SpCaseConfig::getAdminAuditStatus, auditStatus);
        }

        Page<SpCaseConfig> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<SpCaseConfig> result = caseConfigMapper.selectPage(page, wrapper);

        // 批量查询创建者姓名
        Set<Long> creatorIds = result.getRecords().stream()
                .map(SpCaseConfig::getCreatorId)
                .filter(id -> id != null)
                .collect(Collectors.toSet());
        Map<Long, String> creatorNameMap = batchQueryUserNames(creatorIds);

        List<CaseAuditVO> voList = result.getRecords().stream()
                .map(c -> CaseAuditVO.builder()
                        .caseId(c.getId())
                        .title(c.getTitle())
                        .department(c.getDepartment())
                        .difficulty(c.getDifficulty())
                        .creatorId(c.getCreatorId())
                        .creatorName(c.getCreatorId() != null ? creatorNameMap.get(c.getCreatorId()) : null)
                        .auditStatus(c.getAdminAuditStatus())
                        .createdAt(c.getCreatedAt())
                        .build())
                .collect(Collectors.toList());

        return PageResult.of(result, voList);
    }

    @Override
    public CaseAuditDetailVO caseAuditDetail(Long caseId) {
        SpCaseConfig c = caseConfigMapper.selectById(caseId);
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        String creatorName = null;
        if (c.getCreatorId() != null) {
            creatorName = batchQueryUserNames(Set.of(c.getCreatorId())).get(c.getCreatorId());
        }
        return CaseAuditDetailVO.builder()
                .caseId(c.getId())
                .title(c.getTitle())
                .department(c.getDepartment())
                .difficulty(c.getDifficulty())
                .creatorId(c.getCreatorId())
                .creatorName(creatorName)
                .patientProfile(c.getPatientProfile())
                .hiddenDisease(c.getHiddenDisease())
                .knowledgeTags(c.getKnowledgeTags())
                .presetExams(c.getPresetExams())
                .standardPath(c.getStandardPathJson())
                .referenceAnswer(c.getReferenceAnswer())
                .scoringPoints(c.getScoringPointsJson())
                .sourceCaseId(c.getSourceCaseId())
                .adminAuditStatus(c.getAdminAuditStatus())
                .createdAt(c.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void approveCase(Long caseId) {
        SpCaseConfig caseConfig = caseConfigMapper.selectById(caseId);
        if (caseConfig == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }

        String beforeJson = toJson(Map.of("adminAuditStatus", caseConfig.getAdminAuditStatus()));

        caseConfig.setAdminAuditStatus(2);
        caseConfigMapper.updateById(caseConfig);

        String afterJson = toJson(Map.of("adminAuditStatus", 2));

        auditLogService.record("case_audit_approve", "sp_case_config", caseId, beforeJson, afterJson);
        log.info("病例审核通过: caseId={}", caseId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void rejectCase(Long caseId) {
        SpCaseConfig caseConfig = caseConfigMapper.selectById(caseId);
        if (caseConfig == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }

        String beforeJson = toJson(Map.of("adminAuditStatus", caseConfig.getAdminAuditStatus()));

        caseConfig.setAdminAuditStatus(3);
        caseConfigMapper.updateById(caseConfig);

        String afterJson = toJson(Map.of("adminAuditStatus", 3));

        auditLogService.record("case_audit_reject", "sp_case_config", caseId, beforeJson, afterJson);
        log.info("病例审核驳回: caseId={}", caseId);
    }

    // ==================== 基础题审核（题库闭环） ====================

    @Override
    public PageResult<QuestionAuditVO> questionAuditList(PageParam param, Integer auditStatus) {
        LambdaQueryWrapper<PracticeQuestion> wrapper = new LambdaQueryWrapper<PracticeQuestion>()
                .eq(PracticeQuestion::getStatus, 1)
                .orderByDesc(PracticeQuestion::getCreatedAt);
        if (auditStatus != null) {
            // 前端按「待审核(1)/已通过(2)/已驳回(3)」分类筛选
            wrapper.eq(PracticeQuestion::getAdminAuditStatus, auditStatus);
        }

        Page<PracticeQuestion> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<PracticeQuestion> result = questionMapper.selectPage(page, wrapper);

        Set<Long> submitterIds = result.getRecords().stream()
                .map(PracticeQuestion::getSubmitterId)
                .filter(id -> id != null)
                .collect(Collectors.toSet());
        Map<Long, String> nameMap = batchQueryUserNames(submitterIds);

        List<QuestionAuditVO> voList = result.getRecords().stream()
                .map(q -> QuestionAuditVO.builder()
                        .questionId(q.getId())
                        .questionType(q.getQuestionType())
                        .department(q.getDepartment())
                        .knowledgeTag(q.getKnowledgeTag())
                        .title(q.getTitle())
                        .difficulty(q.getDifficulty())
                        .submitterId(q.getSubmitterId())
                        .submitterName(q.getSubmitterId() != null ? nameMap.get(q.getSubmitterId()) : null)
                        .auditStatus(q.getAdminAuditStatus())
                        .createdAt(q.getCreatedAt())
                        .build())
                .collect(Collectors.toList());
        return PageResult.of(result, voList);
    }

    @Override
    public TeacherQuestionVO questionAuditDetail(Long questionId) {
        PracticeQuestion q = questionMapper.selectById(questionId);
        if (q == null) {
            throw new BizException(ResultCode.QUESTION_NOT_FOUND, "题目不存在");
        }
        return TeacherQuestionVO.builder()
                .id(q.getId())
                .questionType(q.getQuestionType())
                .department(q.getDepartment())
                .knowledgeTag(q.getKnowledgeTag())
                .title(q.getTitle())
                .options(parseQuestionOptions(q))
                .answer(q.getAnswer())
                .explanation(q.getExplanation())
                .difficulty(q.getDifficulty())
                .sourceTextbookId(q.getSourceTextbookId())
                .adminAuditStatus(q.getAdminAuditStatus())
                .rejectReason(q.getRejectReason())
                .createdAt(q.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void approveQuestion(Long questionId) {
        PracticeQuestion q = questionMapper.selectById(questionId);
        if (q == null) {
            throw new BizException(ResultCode.QUESTION_NOT_FOUND);
        }
        String beforeJson = toJson(Map.of("adminAuditStatus", q.getAdminAuditStatus()));

        q.setAdminAuditStatus(2);
        q.setRejectReason(null);
        questionMapper.updateById(q);

        String afterJson = toJson(Map.of("adminAuditStatus", 2));
        auditLogService.record("question_audit_approve", "practice_question", questionId, beforeJson, afterJson);
        log.info("基础题审核通过: questionId={}", questionId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void rejectQuestion(Long questionId, RejectDTO dto) {
        PracticeQuestion q = questionMapper.selectById(questionId);
        if (q == null) {
            throw new BizException(ResultCode.QUESTION_NOT_FOUND);
        }
        String beforeJson = toJson(Map.of("adminAuditStatus", q.getAdminAuditStatus()));

        q.setAdminAuditStatus(3);
        q.setRejectReason(dto.getReason());
        questionMapper.updateById(q);

        String afterJson = toJson(Map.of("adminAuditStatus", 3, "rejectReason", dto.getReason()));
        auditLogService.record("question_audit_reject", "practice_question", questionId, beforeJson, afterJson);
        log.info("基础题审核驳回: questionId={}, reason={}", questionId, dto.getReason());
    }

    private List<String> parseQuestionOptions(PracticeQuestion q) {
        if (!StringUtils.hasText(q.getOptionsJson())) {
            return new ArrayList<>();
        }
        try {
            return objectMapper.readValue(q.getOptionsJson(),
                    new com.fasterxml.jackson.core.type.TypeReference<List<String>>() {
                    });
        } catch (Exception e) {
            log.warn("解析题目选项失败: questionId={}", q.getId());
            return new ArrayList<>();
        }
    }

    // ==================== 教材管理 + 向量化入库（教材闭环） ====================

    @Override
    public PageResult<TextbookAdminVO> textbookList(PageParam param) {
        LambdaQueryWrapper<Textbook> wrapper = new LambdaQueryWrapper<Textbook>()
                .orderByDesc(Textbook::getCreatedAt);
        Page<Textbook> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<Textbook> result = textbookMapper.selectPage(page, wrapper);

        Set<Long> creatorIds = result.getRecords().stream()
                .map(Textbook::getCreatorId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<Long, String> nameMap = batchQueryUserNames(creatorIds);

        List<TextbookAdminVO> voList = result.getRecords().stream()
                .map(tb -> TextbookAdminVO.builder()
                        .id(tb.getId())
                        .title(tb.getTitle())
                        .edition(tb.getEdition())
                        .department(tb.getDepartment())
                        .author(tb.getAuthor())
                        .publisher(tb.getPublisher())
                        .coverUrl(tb.getCoverUrl())
                        .fileUrl(tb.getFileUrl())
                        .description(tb.getDescription())
                        .pageCount(tb.getPageCount())
                        .status(tb.getStatus())
                        .ingestStatus(tb.getIngestStatus())
                        .ingestError(tb.getIngestError())
                        .lastIngestAt(tb.getLastIngestAt())
                        .ingestionId(tb.getIngestionId())
                        .ingestRetryCount(tb.getIngestRetryCount())
                        .ingestAutoRetryCount(tb.getIngestAutoRetryCount())
                        .ingestTriggerSource(tb.getIngestTriggerSource())
                        .creatorId(tb.getCreatorId())
                        .creatorName(tb.getCreatorId() != null ? nameMap.get(tb.getCreatorId()) : null)
                        .createdAt(tb.getCreatedAt())
                        .build())
                .collect(Collectors.toList());
        return PageResult.of(result, voList);
    }

    /** 教材入库任务「处理中」超过该时长视为任务丢失，允许重新触发（防止状态永久卡死） */
    private static final java.time.Duration INGEST_STALE_AFTER = java.time.Duration.ofMinutes(30);

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> triggerTextbookIngest(Long textbookId) {
        Textbook tb = textbookMapper.selectById(textbookId);
        if (tb == null) {
            throw new BizException(ResultCode.NOT_FOUND, "教材不存在");
        }
        if (tb.getStatus() == null || tb.getStatus() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "教材已下架，请先上架后再入库");
        }
        if (tb.getIngestStatus() != null && tb.getIngestStatus() == 1) {
            // 处理中但超过阈值：AI worker 可能已崩溃/任务丢失，放行重新触发（新任务替换，旧任务迟到回调按 ingestionId 丢弃）
            LocalDateTime last = tb.getLastIngestAt();
            boolean stale = last == null || last.plus(INGEST_STALE_AFTER).isBefore(LocalDateTime.now());
            if (!stale) {
                throw new BizException(ResultCode.BAD_REQUEST, "教材正在入库中，请勿重复触发");
            }
            log.warn("教材入库处理中已超过 {} 分钟，允许重新触发: textbookId={} lastIngestAt={}",
                    INGEST_STALE_AFTER.toMinutes(), textbookId, last);
        }
        if (!StringUtils.hasText(tb.getFileUrl())) {
            throw new BizException(ResultCode.BAD_REQUEST, "教材缺少电子书文件，无法入库");
        }

        // fileUrl = /uploads/ebooks/xxx.pdf → objectKey = ebooks/xxx.pdf（AI 对象存储根内的相对路径）
        String fileUrl = tb.getFileUrl();
        String objectKey = fileUrl;
        int uploadPrefix = fileUrl.indexOf("/uploads/");
        if (uploadPrefix >= 0) {
            objectKey = fileUrl.substring(uploadPrefix + "/uploads/".length());
        }
        if (!StringUtils.hasText(objectKey)) {
            throw new BizException(ResultCode.BAD_REQUEST, "教材文件地址解析失败，无法入库");
        }

        String beforeJson = toJson(Map.of("ingestStatus", tb.getIngestStatus()));

        // 每次触发生成唯一 attemptKey：AI 幂等键含 attemptKey，保证「失败重试/重新入库」真正创建新任务并重跑
        String attemptId = java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        Map<String, Object> result = aiPlatformClient.ingestKnowledge(
                textbookId, objectKey,
                tb.getTitle(), tb.getEdition(), tb.getDepartment(), attemptId);
        if (result == null || result.get("ingestionId") == null) {
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI 入库服务不可用，请稍后重试");
        }

        // 异步任务已接收：标记处理中，完成由 AI 回调 /api/internal/knowledge/callback 置 2/3
        tb.setIngestStatus(1);
        tb.setIngestError(null);
        tb.setIngestionId(String.valueOf(result.get("ingestionId")));
        tb.setIngestRetryCount(tb.getIngestRetryCount() == null ? 1 : tb.getIngestRetryCount() + 1);
        // 管理员手动重试 = 人为介入，重置自动对账重试预算并标记触发来源为「手动」，
        // 让自动对账任务从零计数，避免把自动重试耗尽的历史一起带到新任务上。
        tb.setIngestAutoRetryCount(0);
        tb.setIngestTriggerSource(Textbook.INGEST_TRIGGER_MANUAL);
        tb.setLastIngestAt(java.time.LocalDateTime.now());
        textbookMapper.updateById(tb);

        String afterJson = toJson(Map.of("ingestStatus", 1));
        auditLogService.record("textbook_ingest_trigger", "textbook", textbookId, beforeJson, afterJson);
        log.info("触发教材入库: textbookId={} objectKey={} ingestionId={} retryCount={}",
                textbookId, objectKey, result.get("ingestionId"), tb.getIngestRetryCount());
        return result;
    }

    @Override
    public Map<String, Object> textbookIngestTask(Long textbookId) {
        Textbook tb = textbookMapper.selectById(textbookId);
        if (tb == null) {
            throw new BizException(ResultCode.NOT_FOUND, "教材不存在");
        }
        if (!StringUtils.hasText(tb.getIngestionId())) {
            // 尚未触发过入库
            Map<String, Object> empty = new HashMap<>();
            empty.put("ingestionId", null);
            empty.put("status", "NONE");
            empty.put("attempts", 0);
            empty.put("errorMessage", null);
            return empty;
        }
        Map<String, Object> detail = aiPlatformClient.getAiTaskDetail(tb.getIngestionId());
        if (detail == null) {
            // AI 中台不可达或任务已过期：返回本地持久化信息，管理端仍可判断
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("ingestionId", tb.getIngestionId());
            fallback.put("status", "AI_TASK_UNAVAILABLE");
            fallback.put("attempts", null);
            fallback.put("errorMessage", "AI 中台不可达或任务已过期（Redis 中无记录），本地入库状态：" + ingestStatusLabel(tb.getIngestStatus()));
            return fallback;
        }
        detail.putIfAbsent("ingestStatus", tb.getIngestStatus());
        return detail;
    }

    private String ingestStatusLabel(Integer status) {
        if (status == null) return "未入库";
        return switch (status) {
            case 1 -> "处理中";
            case 2 -> "已入库";
            case 3 -> "失败";
            default -> "未入库";
        };
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void toggleTextbook(Long textbookId) {
        Textbook tb = textbookMapper.selectById(textbookId);
        if (tb == null) {
            throw new BizException(ResultCode.NOT_FOUND, "教材不存在");
        }
        tb.setStatus(Objects.equals(tb.getStatus(), 1) ? 0 : 1);
        textbookMapper.updateById(tb);
        log.info("教材上/下架切换: textbookId={} status={}", textbookId, tb.getStatus());
    }

    // ==================== 系统配置（PRD 4.16） ====================

    @Override
    public List<SysConfigVO> listSysConfig() {
        return sysConfigMapper.selectList(
                        new LambdaQueryWrapper<SysConfig>()
                                .orderByAsc(SysConfig::getConfigKey))
                .stream()
                .map(c -> SysConfigVO.builder()
                        .id(c.getId())
                        .configKey(c.getConfigKey())
                        .configValue(c.getConfigValue())
                        .configType(c.getConfigType())
                        .updatedAt(c.getUpdatedAt())
                        .build())
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateSysConfig(SysConfigUpdateDTO dto) {
        SysConfig existing = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>()
                        .eq(SysConfig::getConfigKey, dto.getConfigKey()));

        if (existing != null) {
            // 更新
            String beforeJson = toJson(existing);

            existing.setConfigValue(dto.getConfigValue());
            existing.setConfigType(dto.getConfigType());
            sysConfigMapper.updateById(existing);

            String afterJson = toJson(existing);
            auditLogService.record("sys_config_update", "sys_config", existing.getId(), beforeJson, afterJson);
            log.info("系统配置更新: key={}", dto.getConfigKey());
        } else {
            // 插入
            SysConfig config = new SysConfig();
            config.setConfigKey(dto.getConfigKey());
            config.setConfigValue(dto.getConfigValue());
            config.setConfigType(dto.getConfigType());
            sysConfigMapper.insert(config);

            String afterJson = toJson(config);
            auditLogService.record("sys_config_create", "sys_config", config.getId(), null, afterJson);
            log.info("系统配置新增: key={}", dto.getConfigKey());
        }
    }

    // ==================== 审计日志查询（PRD 4.17） ====================

    @Override
    public PageResult<AuditLogVO> auditLogList(PageParam param, Long operatorId, String action,
                                                String targetType, LocalDate startDate, LocalDate endDate) {
        LambdaQueryWrapper<AuditLog> wrapper = new LambdaQueryWrapper<>();
        if (operatorId != null) {
            wrapper.eq(AuditLog::getOperatorId, operatorId);
        }
        if (StringUtils.hasText(action)) {
            wrapper.eq(AuditLog::getAction, action);
        }
        if (StringUtils.hasText(targetType)) {
            wrapper.eq(AuditLog::getTargetType, targetType);
        }
        if (startDate != null) {
            wrapper.ge(AuditLog::getCreatedAt, startDate.atStartOfDay());
        }
        if (endDate != null) {
            wrapper.le(AuditLog::getCreatedAt, endDate.atTime(23, 59, 59));
        }
        wrapper.orderByDesc(AuditLog::getCreatedAt);

        Page<AuditLog> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<AuditLog> result = auditLogMapper.selectPage(page, wrapper);

        // 批量查询操作人姓名
        Set<Long> operatorIds = result.getRecords().stream()
                .map(AuditLog::getOperatorId)
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());
        Map<Long, String> operatorNameMap = batchQueryUserNames(operatorIds);

        List<AuditLogVO> voList = result.getRecords().stream()
                .map(al -> AuditLogVO.builder()
                        .id(al.getId())
                        .operatorId(al.getOperatorId())
                        .operatorName(al.getOperatorId() != null && al.getOperatorId() > 0
                                ? operatorNameMap.get(al.getOperatorId()) : null)
                        .operatorRole(al.getOperatorRole())
                        .action(al.getAction())
                        .targetType(al.getTargetType())
                        .targetId(al.getTargetId())
                        .beforeJson(al.getBeforeJson())
                        .afterJson(al.getAfterJson())
                        .ipAddress(al.getIpAddress())
                        .createdAt(al.getCreatedAt())
                        .build())
                .collect(Collectors.toList());

        return PageResult.of(result, voList);
    }

    // ==================== 用户管理（PRD 4.14 / 4.17） ====================

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void freezeUser(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() != null && (user.getRole() == 4 || user.getRole() == 5)) {
            throw new BizException(ResultCode.BAD_REQUEST, "不允许冻结管理员/运维账号");
        }
        String beforeJson = toJson(Map.of("status", user.getStatus()));
        // P1：冻结时同步递增 credential_version，撤销该用户所有已签发的 access/refresh token。
        // MustChangePasswordInterceptor 的版本校验会立即拒绝旧 token，防止冻结后旧 token
        // 在 24h access 有效期内继续操作。使用 UpdateWrapper + setSql 原子递增，避免
        // LambdaUpdateWrapper 的 lambda cache 在隔离测试中未预热导致 NPE。
        //
        // 复审 F5 修复：补 .eq("credential_version", ...) 与 unfreezeUser/approve/reject 对称，
        // 封死 freeze→unfreeze→迟到 freeze 的 ABA：
        //   t0 A 读库 (status=0, cv=v) → t1 B 冻结成功 (cv v→v+1) → t2 解冻 (cv 不变)
        //   → t3 迟到的 A 执行：仅有 .eq("status",0) 仍匹配（状态已回到 0）→ 错误冻结并杀新 token。
        //   加 cv CAS 后 A 持有的 v 与 DB 的 v+1 不匹配 → rows=0 → 拒绝。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("status", 0)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("status", 1)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "用户不存在、已删除、已被冻结或账号状态已变更");
        }
        String afterJson = toJson(Map.of("status", 1));
        auditLogService.record("user_freeze", "user", userId, beforeJson, afterJson);
        log.info("账号冻结: userId={}, operator={}", userId, UserContext.requireUserId());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void unfreezeUser(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        // H4 修复：禁止解冻仍使用默认弱密码的账号。
        // ProdSecurityInitializer 会冻结密码仍为 123456 的演示账号，但解冻时不检查密码，
        // 其他管理员一旦解冻 admin01，公开弱密码立即重新可用。
        if (passwordEncoder.matches(DEMO_PASSWORD, user.getPasswordHash())) {
            throw new BizException(ResultCode.BAD_REQUEST,
                    "该账号仍在使用默认弱密码，请先重置密码后再解冻");
        }
        String beforeJson = toJson(Map.of("status", user.getStatus()));
        // 解冻不递增 credential_version：冻结时已撤销旧 token，用户解冻后需重新登录获取新 token。
        // 若解冻也递增版本，会导致用户刚解冻就被迫再次重登（体验差且无安全收益）。
        //
        // P0-4 修复：使用窄字段 UpdateWrapper 只更新 status，不使用 updateById(user)。
        // updateById 会写入完整实体快照，并发场景下可能把另一个事务已递增的 credential_version
        // 或修改的 role/passwordHash 写回旧值，导致撤销被回滚。窄字段 UPDATE 只动 status 列。
        //
        // P1-1 修复：CAS 条件增加 .eq("status", 1)，仅当前为冻结状态才解冻。
        // 防止迟到 unfreeze 覆盖较新的 freeze（管理员先冻结再解冻，但迟到的解冻请求
        // 在冻结之后执行，把已冻结的账号又解冻了）。
        //
        // H3 修复：CAS 增加 .eq("credential_version", user.getCredentialVersion()) 消除 ABA。
        // 冻结递增 cv → 解冻不递增 → 再次冻结递增 cv。旧解冻持有的旧 cv 不匹配，防止
        // 1→0→1 后旧解冻请求撤销最新冻结。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("status", 1)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("status", 0));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "账号未处于冻结状态，无需解冻");
        }
        String afterJson = toJson(Map.of("status", 0));
        auditLogService.record("user_unfreeze", "user", userId, beforeJson, afterJson);
        log.info("账号解冻: userId={}, operator={}", userId, UserContext.requireUserId());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void changeUserRole(Long userId, Integer newRole) {
        if (newRole == null || newRole < 0 || newRole > 3) {
            throw new BizException(ResultCode.BAD_REQUEST, "目标角色非法，仅支持 0-3");
        }
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() != null && (user.getRole() == 4 || user.getRole() == 5)) {
            throw new BizException(ResultCode.BAD_REQUEST, "不允许修改管理员/运维角色");
        }
        if (newRole.equals(user.getRole())) {
            return; // 无变化
        }
        String beforeJson = toJson(Map.of("role", user.getRole()));
        // 角色变更后重置审核状态：教师(1)需重新认证，其他角色置为已通过(2)
        Integer newAuditStatus = (newRole == 1) ? 0 : 2;
        // P1：角色变更时同步递增 credential_version，撤销携带旧角色的 access token。
        // PermissionInterceptor 信任 JWT 中的 role claim，若不递增版本，降权/升权后的
        // 旧 token 最长 24h 仍以旧角色访问端点（如学生 token 升级为教师后可调教师接口，
        // 或教师 token 降级为学生后仍可调教师接口）。递增版本后旧 token 被立即拒绝，
        // 用户必须重新登录获取携带新角色的 token。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .set("role", newRole)
                        .set("audit_status", newAuditStatus)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在或已被删除");
        }
        Map<String, Object> after = new HashMap<>();
        after.put("role", newRole);
        after.put("auditStatus", newAuditStatus);
        auditLogService.record("user_role_change", "user", userId, beforeJson, toJson(after));
        log.info("用户角色变更: userId={} {}->{} operator={}",
                userId, beforeJson, newRole, UserContext.requireUserId());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void createAuditor(CreateAuditorDTO dto) {
        Long exists = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>().eq(SysUser::getUsername, dto.getUsername()));
        if (exists != null && exists > 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "账号已存在");
        }
        SysUser u = new SysUser();
        u.setUsername(dto.getUsername());
        u.setPasswordHash(passwordEncoder.encode(dto.getPassword()));
        u.setRealName(dto.getRealName());
        u.setDepartment(dto.getDepartment());
        u.setRole(6);      // 普通审核员
        u.setAuditStatus(2);
        u.setStatus(0);
        u.setMustChangePassword(false);
        u.setCredentialVersion(0);
        userMapper.insert(u);

        auditLogService.record("user_create_auditor", "user", u.getId(),
                null, toJson(Map.of("role", 6, "username", dto.getUsername(), "realName", dto.getRealName())));
        log.info("开通普通审核员账号: username={}, realName={}, operator={}",
                dto.getUsername(), dto.getRealName(), UserContext.requireUserId());
    }

    // ==================== 工具方法 ====================

    /**
     * 教师审核 VO 转换，手机号脱敏
     */
    private TeacherAuditVO toTeacherAuditVO(SysUser user) {
        return TeacherAuditVO.builder()
                .userId(user.getId())
                .username(user.getUsername())
                .realName(user.getRealName())
                .phone(maskPhone(user.getPhone()))
                .certificateNo(user.getTeacherCertificateNo())
                .department(user.getDepartment())
                .auditStatus(user.getAuditStatus())
                .createdAt(user.getCreatedAt())
                .build();
    }

    /**
     * 手机号脱敏（PRD 10.3）：前3位 + **** + 后4位
     */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }

    /**
     * 批量查询用户姓名
     */
    private Map<Long, String> batchQueryUserNames(Set<Long> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new HashMap<>();
        }
        List<SysUser> users = userMapper.selectList(
                new LambdaQueryWrapper<SysUser>()
                        .in(SysUser::getId, userIds));
        return users.stream()
                .collect(Collectors.toMap(SysUser::getId, u -> u.getRealName() != null ? u.getRealName() : u.getUsername(), (a, b) -> a));
    }

    // ==================== 人数管理（列表查询 / 统计 / 重置密码） ====================

    /** 角色中文名映射，前端无需各自维护一份 */
    private static final Map<Integer, String> ROLE_NAMES = Map.of(
            0, "学生",
            1, "教师",
            2, "教学秘书",
            3, "教研室主任",
            4, "超级管理员",
            5, "运维",
            6, "审核员");

    @Override
    public PageResult<AdminUserVO> listUsers(PageParam param, Integer role, Integer status, String keyword) {
        PageParam p = param != null ? param : new PageParam();
        int pageNum = (p.getPageNum() == null || p.getPageNum() < 1) ? 1 : p.getPageNum();
        int pageSize = (p.getPageSize() == null || p.getPageSize() < 1) ? 10 : Math.min(p.getPageSize(), 100);

        LambdaQueryWrapper<SysUser> qw = new LambdaQueryWrapper<>();
        if (role != null) {
            qw.eq(SysUser::getRole, role);
        }
        if (status != null) {
            qw.eq(SysUser::getStatus, status);
        }
        // 关键词：用户名 / 姓名 / 学校 / 手机号 模糊匹配
        if (StringUtils.hasText(keyword)) {
            String kw = keyword.trim();
            qw.and(w -> w.like(SysUser::getUsername, kw)
                    .or().like(SysUser::getRealName, kw)
                    .or().like(SysUser::getSchoolName, kw)
                    .or().like(SysUser::getPhone, kw));
        }
        // 最近登录时间倒序，便于管理员快速定位活跃/僵尸账号
        qw.orderByDesc(SysUser::getLastLoginAt).orderByDesc(SysUser::getCreatedAt);

        IPage<SysUser> page = userMapper.selectPage(new Page<>(pageNum, pageSize), qw);

        List<AdminUserVO> vos = page.getRecords().stream().map(u -> AdminUserVO.builder()
                .id(u.getId())
                .username(u.getUsername())
                .realName(u.getRealName())
                .role(u.getRole())
                .roleName(ROLE_NAMES.getOrDefault(u.getRole(), "未知"))
                .classId(u.getClassId())
                .className(u.getClassName())
                .schoolName(u.getSchoolName())
                .grade(u.getGrade())
                .department(u.getDepartment())
                .phone(maskPhone(u.getPhone()))
                .auditStatus(u.getAuditStatus())
                .status(u.getStatus())
                .mustChangePassword(u.getMustChangePassword())
                .lastLoginAt(u.getLastLoginAt())
                .createdAt(u.getCreatedAt())
                .build()).collect(Collectors.toList());

        return PageResult.of(page, vos);
    }

    @Override
    public AdminUserStatsVO userStats() {
        // 一次分组聚合拿到全部角色人数，避免每个角色发一条 COUNT
        List<Map<String, Object>> rows = userMapper.selectMaps(
                new QueryWrapper<SysUser>().select("role", "COUNT(*) AS cnt").groupBy("role"));

        Map<Integer, Long> byRole = new HashMap<>();
        long total = 0;
        for (Map<String, Object> row : rows) {
            Object r = row.get("role");
            Object c = row.get("cnt");
            if (r == null || c == null) {
                continue;
            }
            long cnt = ((Number) c).longValue();
            byRole.put(((Number) r).intValue(), cnt);
            total += cnt;
        }

        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime weekStart = LocalDate.now().minusDays(6).atStartOfDay();

        return AdminUserStatsVO.builder()
                .totalUsers(total)
                .studentCount(byRole.getOrDefault(0, 0L))
                .teacherCount(byRole.getOrDefault(1, 0L))
                .teachingSecretaryCount(byRole.getOrDefault(2, 0L))
                .deptHeadCount(byRole.getOrDefault(3, 0L))
                .adminCount(byRole.getOrDefault(4, 0L))
                .opsCount(byRole.getOrDefault(5, 0L))
                .auditorCount(byRole.getOrDefault(6, 0L))
                .frozenCount(userMapper.selectCount(new LambdaQueryWrapper<SysUser>().eq(SysUser::getStatus, 1)))
                .pendingTeacherCount(userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 1).eq(SysUser::getAuditStatus, 1)))
                .todayNewUsers(userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                        .ge(SysUser::getCreatedAt, todayStart)))
                .weekNewUsers(userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                        .ge(SysUser::getCreatedAt, weekStart)))
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public String resetPassword(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        // 生成随机强密码：避开 DEMO_PASSWORD，保证重置后的账号能通过 unfreezeUser 的弱密码校验。
        // 字符集剔除 0/O/1/l/I 等易混淆字符，便于管理员口头传达。
        String newPassword = generateTempPassword();
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("is_deleted", 0)
                        .set("password_hash", passwordEncoder.encode(newPassword))
                        .set("must_change_password", 1)
                        // 递增凭证版本，撤销该用户全部已签发 token，强制重新登录
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在或已被删除");
        }
        auditLogService.record("user_reset_password", "user", userId, null, null);
        log.info("管理员重置密码: userId={}, operator={}", userId, UserContext.requireUserId());
        return newPassword;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public int batchFreeze(List<Long> userIds, boolean freeze) {
        if (userIds == null || userIds.isEmpty()) {
            return 0;
        }
        // 去重，避免重复 ID 导致计数虚高
        Set<Long> ids = userIds.stream().filter(Objects::nonNull).collect(Collectors.toSet());
        if (ids.isEmpty()) {
            return 0;
        }
        int changed = 0;
        for (Long id : ids) {
            try {
                if (freeze) {
                    freezeUser(id);
                } else {
                    unfreezeUser(id);
                }
                changed++;
            } catch (BizException e) {
                // 单个失败不影响其余账号（如已冻结、管理员账号等），记录后继续
                log.warn("批量{}跳过: userId={}, reason={}", freeze ? "冻结" : "解冻", id, e.getMessage());
            }
        }
        log.info("批量{}账号: 请求 {} 个，成功 {} 个, operator={}",
                freeze ? "冻结" : "解冻", ids.size(), changed, UserContext.requireUserId());
        return changed;
    }

    /** 生成 10 位临时强密码（剔除易混淆字符 0/O/1/l/I） */
    private String generateTempPassword() {
        String chars = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
        StringBuilder sb = new StringBuilder(10);
        for (int i = 0; i < 10; i++) {
            sb.append(chars.charAt(RANDOM.nextInt(chars.length())));
        }
        return sb.toString();
    }

    /**
     * 对象转 JSON 字符串，失败返回 null
     */
    private String toJson(Object obj) {
        if (obj == null) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            log.warn("JSON 序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
