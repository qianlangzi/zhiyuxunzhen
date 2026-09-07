package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.AssignmentInstance;
import com.zhiyu.entity.AssignmentItem;
import com.zhiyu.entity.AssignmentItemProgress;
import com.zhiyu.entity.AssignmentTargetClass;
import com.zhiyu.entity.MedicalRecordReview;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AssignmentItemMapper;
import com.zhiyu.mapper.AssignmentItemProgressMapper;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.AssignmentTargetClassMapper;
import com.zhiyu.mapper.MedicalRecordReviewMapper;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.TeacherReviewService;
import com.zhiyu.service.dto.ReviewOverrideDTO;
import com.zhiyu.vo.TeacherReviewVO;
import com.zhiyu.vo.TeacherReviewQueueVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 教师复核 AI 批阅服务实现（PRD 4.4.4 / 5.3 第 7 步）
 * 教师只能复核本人布置作业的实例；覆盖后实例状态置为 5（已完成）
 * 所有覆盖操作写入 medical_record_review 和 audit_log
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherReviewServiceImpl implements TeacherReviewService {

    private final MedicalRecordReviewMapper reviewMapper;
    private final AssignmentInstanceMapper instanceMapper;
    private final AssignmentItemMapper itemMapper;
    private final AssignmentItemProgressMapper progressMapper;
    private final SpCaseConfigMapper caseMapper;
    private final AssignmentMapper assignmentMapper;
    private final AssignmentTargetClassMapper targetClassMapper;
    private final TeachingClassMapper classMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;
    private final SysUserMapper userMapper;
    private final com.zhiyu.client.AiPlatformClient aiPlatformClient;
    private final PracticeQuestionMapper questionMapper;
    private final StudentMistakesMapper mistakesMapper;
    private final com.zhiyu.service.support.MistakeAnalysisTrigger mistakeAnalysisTrigger;

    /** 主观题低于此分（百分制）收入错题本，走失分维度归因 */
    private static final double ESSAY_MISTAKE_SCORE_THRESHOLD = 60.0;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> essayReview(com.zhiyu.service.dto.EssayReviewDTO dto) {
        Long teacherId = UserContext.requireUserId();

        // 绑定任务项进度：校验归属、推导学生ID、必要时从 DB 补齐题目/答案（保证真实数据而非伪造）
        Long itemProgressId = dto.getItemProgressId();
        AssignmentItemProgress progress = null;
        AssignmentInstance inst = null;
        Assignment assignment = null;
        Long instanceId = dto.getInstanceId();
        if (itemProgressId != null) {
            progress = progressMapper.selectById(itemProgressId);
            if (progress != null) {
                inst = instanceMapper.selectById(progress.getInstanceId());
                if (instanceId == null && inst != null) {
                    instanceId = inst.getId();
                }
                if (inst != null) {
                    assignment = assignmentMapper.selectById(inst.getAssignmentId());
                    if (assignment == null || !teacherId.equals(assignment.getTeacherId())) {
                        throw new BizException(ResultCode.FORBIDDEN, "只能批改本人布置作业的任务");
                    }
                }
                if (dto.getStudentId() == null) {
                    dto.setStudentId(progress.getStudentId());
                }
            }
        }

        // 补齐题目与学生作答（来自任务项关联的基础题库 + 学生应答），未配置评分要点时留空由 AI 按通用标准评阅
        if (dto.getQuestionId() != null) {
            if (isBlank(dto.getQuestion())) {
                PracticeQuestion q = questionMapper.selectById(dto.getQuestionId());
                if (q != null) {
                    dto.setQuestion(q.getTitle());
                }
            }
            if (isBlank(dto.getStudentAnswer())) {
                String answer = resolveAnswer(progress, dto.getQuestionId());
                if (answer != null) dto.setStudentAnswer(answer);
            }
        }

        Map<String, Object> result = aiPlatformClient.reviewEssay(
                dto.getQuestion(),
                dto.getScoringPoints() == null ? "" : dto.getScoringPoints(),
                dto.getStudentAnswer(),
                dto.getCaseContext() == null ? "" : dto.getCaseContext(),
                dto.getTextbookRefs() == null ? List.of() : dto.getTextbookRefs());
        if (result == null) {
            log.warn("主观题 AI 批阅失败（AI 中台不可达）: teacherId={}", teacherId);
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "AI 批阅服务不可用，请稍后重试");
        }

        // ---- 落库：写入 AI 批阅记录 + 更新任务项状态（组合包主观题任务）----
        Long reviewId = null;
        if (progress != null && instanceId != null) {
            MedicalRecordReview aiReview = new MedicalRecordReview();
            aiReview.setInstanceId(instanceId);
            aiReview.setAssignmentItemProgressId(itemProgressId);
            aiReview.setReviewerType("AI");
            if (result.get("totalScore") instanceof Number total) {
                aiReview.setTotalScore(BigDecimal.valueOf(total.doubleValue()));
            }
            aiReview.setMistakesJson(buildEssayMistakesJson(result));
            aiReview.setReviewComment(Objects.toString(result.get("reviewComment"), null));
            reviewMapper.insert(aiReview);
            reviewId = aiReview.getId();

            // 任务项状态 -> 待教师复核(4)
            progress.setStatus(4);
            if (aiReview.getTotalScore() != null) {
                progress.setScore(aiReview.getTotalScore());
            }
            progressMapper.updateById(progress);
            if (inst != null) {
                refreshInstanceStatus(inst);
            }
            log.info("教师{}触发主观题AI批阅已落库: itemProgressId={} reviewId={} score={}",
                    teacherId, itemProgressId, reviewId, aiReview.getTotalScore());
        }

        Map<String, Object> out = new HashMap<>();
        out.putAll(result);
        out.put("reviewId", reviewId);
        out.put("assignmentId", dto.getAssignmentId() != null ? dto.getAssignmentId()
                : (assignment == null ? null : assignment.getId()));
        out.put("itemProgressId", itemProgressId);
        out.put("questionId", dto.getQuestionId());
        out.put("studentId", dto.getStudentId());
        out.put("instanceId", instanceId);
        log.info("主观题 AI 批阅完成: teacherId={} questionLen={} answerLen={}",
                teacherId,
                dto.getQuestion() == null ? 0 : dto.getQuestion().length(),
                dto.getStudentAnswer() == null ? 0 : dto.getStudentAnswer().length());
        return out;
    }

    @Override
    public Map<String, Object> getEssayTask(Long itemProgressId) {
        if (itemProgressId == null) {
            return null;
        }
        Long teacherId = UserContext.requireUserId();
        AssignmentItemProgress progress = progressMapper.selectById(itemProgressId);
        if (progress == null) {
            return null;
        }
        AssignmentInstance inst = instanceMapper.selectById(progress.getInstanceId());
        if (inst == null) {
            return null;
        }
        Assignment assignment = assignmentMapper.selectById(inst.getAssignmentId());
        if (assignment == null || !teacherId.equals(assignment.getTeacherId())) {
            return null;
        }
        AssignmentItem item = itemMapper.selectById(progress.getItemId());

        // 定位首个主观题（简答/论述）ID 与对应学生答案；无主观题时回退第一题
        Long questionId = null;
        String answer = null;
        List<Long> ids = item == null ? List.of() : parseQuestionIds(item.getQuestionIds());
        if (!ids.isEmpty()) {
            List<PracticeQuestion> qs = questionMapper.selectBatchIds(ids);
            questionId = qs.stream()
                    .filter(Objects::nonNull)
                    .filter(q -> isSubjective(q.getQuestionType()))
                    .findFirst()
                    .map(PracticeQuestion::getId)
                    .orElse(ids.get(0));
        }
        if (questionId != null && isBlank(progress.getAnswersJson()) == false) {
            answer = resolveAnswer(progress, questionId);
        }
        PracticeQuestion q = questionId == null ? null : questionMapper.selectById(questionId);

        String studentName = "";
        if (progress.getStudentId() != null) {
            SysUser u = userMapper.selectById(progress.getStudentId());
            if (u != null && u.getRealName() != null) {
                studentName = u.getRealName();
            }
        }
        MedicalRecordReview latest = loadLatestReviewByProgress(List.of(progress))
                .get(progress.getId());

        Map<String, Object> map = new HashMap<>();
        map.put("assignmentId", assignment.getId());
        map.put("instanceId", inst.getId());
        map.put("itemProgressId", itemProgressId);
        map.put("itemId", item == null ? null : item.getId());
        map.put("questionId", questionId);
        map.put("question", q == null ? (item == null ? null : item.getTitle()) : q.getTitle());
        // 基础题库当前无独立评分要点字段，如需按要点批阅由教师端临时录入
        map.put("scoringPoints", null);
        map.put("studentAnswer", answer);
        map.put("studentName", studentName);
        map.put("assignmentTitle", assignment.getTitle());
        map.put("latestReviewId", latest == null ? null : latest.getId());
        map.put("latestTotalScore", latest == null ? null : latest.getTotalScore());
        map.put("latestReviewComment", latest == null ? null : latest.getReviewComment());
        return map;
    }

    @Override
    public List<TeacherReviewQueueVO> list(Long classId) {
        Long teacherId = UserContext.requireUserId();
        List<Assignment> assignments = assignmentMapper.selectList(
                new LambdaQueryWrapper<Assignment>().eq(Assignment::getTeacherId, teacherId));
        if (assignments.isEmpty()) return List.of();
        Map<Long, Assignment> assignmentMap = assignments.stream()
                .collect(Collectors.toMap(Assignment::getId, Function.identity()));

        // 按班级过滤：只保留发到指定班级的作业（通过 AssignmentTargetClass 二次关联）
        List<Long> keySet;
        if (classId != null) {
            keySet = targetClassMapper.selectList(
                            new LambdaQueryWrapper<AssignmentTargetClass>()
                                    .in(AssignmentTargetClass::getAssignmentId, assignmentMap.keySet())
                                    .eq(AssignmentTargetClass::getClassId, classId))
                    .stream().map(AssignmentTargetClass::getAssignmentId)
                    .distinct().toList();
        } else {
            keySet = new java.util.ArrayList<>(assignmentMap.keySet());
        }
        if (keySet.isEmpty()) return List.of();
        Set<Long> queryKeys = new HashSet<>(keySet);

        List<TeacherReviewQueueVO> result = new java.util.ArrayList<>();

        // ---------- 存量单病例作业:按作业实例(status>=3) ----------
        List<AssignmentInstance> instances = instanceMapper.selectList(
                new LambdaQueryWrapper<AssignmentInstance>()
                        .in(AssignmentInstance::getAssignmentId, queryKeys)
                        .ge(AssignmentInstance::getStatus, 3)
                        .orderByDesc(AssignmentInstance::getUpdatedAt));
        if (!instances.isEmpty()) {
            Map<Long, String> studentNames = userMapper.selectBatchIds(
                            instances.stream().map(AssignmentInstance::getStudentId)
                                    .filter(Objects::nonNull).distinct().toList())
                    .stream().collect(Collectors.toMap(SysUser::getId, SysUser::getRealName));
            List<MedicalRecordReview> reviews = reviewMapper.selectList(
                    new LambdaQueryWrapper<MedicalRecordReview>()
                            .in(MedicalRecordReview::getInstanceId,
                                    instances.stream().map(AssignmentInstance::getId).toList())
                            .orderByDesc(MedicalRecordReview::getCreatedAt));
            Map<Long, MedicalRecordReview> latest = new HashMap<>();
            reviews.forEach(review -> latest.putIfAbsent(review.getInstanceId(), review));
            Map<Long, Long> firstClassByAssignment = new HashMap<>();
            Map<Long, String> classNameById = loadClassNameMap(assignmentMap, firstClassByAssignment);
            for (AssignmentInstance instance : instances) {
                Assignment assignment = assignmentMap.get(instance.getAssignmentId());
                MedicalRecordReview review = latest.get(instance.getId());
                Long rowClassId = firstClassByAssignment.get(instance.getAssignmentId());
                result.add(TeacherReviewQueueVO.builder()
                        .instanceId(instance.getId())
                        .itemType("CASE")
                        .assignmentId(instance.getAssignmentId())
                        .assignmentTitle(assignment == null ? "" : assignment.getTitle())
                        .classId(rowClassId)
                        .className(rowClassId == null ? "" : classNameById.getOrDefault(rowClassId, ""))
                        .studentName(studentNames.getOrDefault(instance.getStudentId(), ""))
                        .score(review == null ? null : review.getTotalScore())
                        .issue(review == null ? "等待 AI 批阅结果" : review.getReviewComment())
                        .instanceStatus(instance.getStatus())
                        .submitTime(instance.getSubmitTime())
                        .latestReviewId(review == null ? null : review.getId())
                        .build());
            }
        }

        // ---------- 组合任务包:病例任务项进度(status 3/4) ----------
        List<AssignmentItem> caseItems = itemMapper.selectList(
                new LambdaQueryWrapper<AssignmentItem>()
                        .in(AssignmentItem::getAssignmentId, queryKeys)
                        .eq(AssignmentItem::getItemType, "CASE"));
        if (!caseItems.isEmpty()) {
            List<Long> itemIds = caseItems.stream().map(AssignmentItem::getId).toList();
            List<AssignmentItemProgress> progresses = progressMapper.selectList(
                    new LambdaQueryWrapper<AssignmentItemProgress>()
                            .in(AssignmentItemProgress::getItemId, itemIds)
                            .in(AssignmentItemProgress::getStatus, 3, 4)
                            .orderByDesc(AssignmentItemProgress::getUpdatedAt));
            if (!progresses.isEmpty()) {
                Map<Long, AssignmentItem> itemMap = caseItems.stream()
                        .collect(Collectors.toMap(AssignmentItem::getId, Function.identity()));
                List<Long> studentIds = progresses.stream().map(AssignmentItemProgress::getStudentId)
                        .filter(Objects::nonNull).distinct().toList();
                Map<Long, String> studentNames = studentIds.isEmpty() ? Map.of()
                        : userMapper.selectBatchIds(studentIds).stream()
                                .collect(Collectors.toMap(SysUser::getId, SysUser::getRealName));
                List<Long> instIds = progresses.stream().map(AssignmentItemProgress::getInstanceId)
                        .filter(Objects::nonNull).distinct().toList();
                Map<Long, AssignmentInstance> instMap = instIds.isEmpty() ? Map.of()
                        : instanceMapper.selectBatchIds(instIds).stream()
                                .collect(Collectors.toMap(AssignmentInstance::getId, Function.identity()));
                Map<Long, Long> caseIdToItem = new HashMap<>();
                Map<Long, String> caseTitleMap = loadCaseTitles(caseItems);
                Map<Long, MedicalRecordReview> latestByProgress = loadLatestReviewByProgress(progresses);
                Map<Long, Long> firstClassByAssignment = new HashMap<>();
                Map<Long, String> classNameById = loadClassNameMap(assignmentMap, firstClassByAssignment);

                for (AssignmentItemProgress p : progresses) {
                    AssignmentItem item = itemMap.get(p.getItemId());
                    AssignmentInstance inst = instMap.get(p.getInstanceId());
                    Assignment assignment = inst == null ? null : assignmentMap.get(inst.getAssignmentId());
                    MedicalRecordReview review = latestByProgress.get(p.getId());
                    Long rowClassId = assignment == null ? null : firstClassByAssignment.get(assignment.getId());
                    result.add(TeacherReviewQueueVO.builder()
                            .instanceId(p.getInstanceId())
                            .itemType("CASE")
                            .itemProgressId(p.getId())
                            .itemId(p.getItemId())
                            .caseTitle(item == null ? "" : caseTitleMap.getOrDefault(item.getCaseId(), ""))
                            .assignmentId(assignment == null ? null : assignment.getId())
                            .assignmentTitle(assignment == null ? "" : assignment.getTitle())
                            .classId(rowClassId)
                            .className(rowClassId == null ? "" : classNameById.getOrDefault(rowClassId, ""))
                            .studentName(studentNames.getOrDefault(p.getStudentId(), ""))
                            .score(review == null ? null : review.getTotalScore())
                            .issue(review == null ? "等待 AI 批阅结果" : review.getReviewComment())
                            .instanceStatus(p.getStatus())
                            .submitTime(p.getSubmitTime())
                            .latestReviewId(review == null ? null : review.getId())
                            .build());
                }
            }
        }

        // ---------- 组合任务包:主观题(PRACTICE)任务项进度(status 3/4，AI 批阅/待教师批改) ----------
        List<AssignmentItem> practiceItems = itemMapper.selectList(
                new LambdaQueryWrapper<AssignmentItem>()
                        .in(AssignmentItem::getAssignmentId, queryKeys)
                        .eq(AssignmentItem::getItemType, "PRACTICE"));
        if (!practiceItems.isEmpty()) {
            List<Long> practiceItemIds = practiceItems.stream().map(AssignmentItem::getId).toList();
            List<AssignmentItemProgress> practiceProgresses = progressMapper.selectList(
                    new LambdaQueryWrapper<AssignmentItemProgress>()
                            .in(AssignmentItemProgress::getItemId, practiceItemIds)
                            .in(AssignmentItemProgress::getStatus, 3, 4)
                            .orderByDesc(AssignmentItemProgress::getUpdatedAt));
            if (!practiceProgresses.isEmpty()) {
                Map<Long, AssignmentItem> practiceItemMap = practiceItems.stream()
                        .collect(Collectors.toMap(AssignmentItem::getId, Function.identity()));
                List<Long> pStudentIds = practiceProgresses.stream()
                        .map(AssignmentItemProgress::getStudentId)
                        .filter(Objects::nonNull).distinct().toList();
                Map<Long, String> pStudentNames = pStudentIds.isEmpty() ? Map.of()
                        : userMapper.selectBatchIds(pStudentIds).stream()
                                .collect(Collectors.toMap(SysUser::getId, SysUser::getRealName));
                List<Long> pInstIds = practiceProgresses.stream()
                        .map(AssignmentItemProgress::getInstanceId)
                        .filter(Objects::nonNull).distinct().toList();
                Map<Long, AssignmentInstance> pInstMap = pInstIds.isEmpty() ? Map.of()
                        : instanceMapper.selectBatchIds(pInstIds).stream()
                                .collect(Collectors.toMap(AssignmentInstance::getId, Function.identity()));
                Map<Long, MedicalRecordReview> pLatest = loadLatestReviewByProgress(practiceProgresses);
                Map<Long, Long> pFirstClassByAssignment = new HashMap<>();
                Map<Long, String> pClassNameById = loadClassNameMap(assignmentMap, pFirstClassByAssignment);

                for (AssignmentItemProgress p : practiceProgresses) {
                    AssignmentItem item = practiceItemMap.get(p.getItemId());
                    AssignmentInstance inst = pInstMap.get(p.getInstanceId());
                    Assignment assignment = inst == null ? null : assignmentMap.get(inst.getAssignmentId());
                    MedicalRecordReview review = pLatest.get(p.getId());
                    Long rowClassId = assignment == null ? null : pFirstClassByAssignment.get(assignment.getId());
                    result.add(TeacherReviewQueueVO.builder()
                            .instanceId(p.getInstanceId())
                            .itemType("PRACTICE")
                            .itemProgressId(p.getId())
                            .itemId(p.getItemId())
                            .caseTitle(item == null ? "" : item.getTitle())
                            .assignmentId(assignment == null ? null : assignment.getId())
                            .assignmentTitle(assignment == null ? "" : assignment.getTitle())
                            .classId(rowClassId)
                            .className(rowClassId == null ? "" : pClassNameById.getOrDefault(rowClassId, ""))
                            .studentName(pStudentNames.getOrDefault(p.getStudentId(), ""))
                            .score(review == null ? null : review.getTotalScore())
                            .issue(review == null ? "等待 AI 批阅结果" : review.getReviewComment())
                            .instanceStatus(p.getStatus())
                            .submitTime(p.getSubmitTime())
                            .latestReviewId(review == null ? null : review.getId())
                            .build());
                }
            }
        }

        result.sort((a, b) -> {
            if (a.getSubmitTime() == null && b.getSubmitTime() == null) return 0;
            if (a.getSubmitTime() == null) return 1;
            if (b.getSubmitTime() == null) return -1;
            return b.getSubmitTime().compareTo(a.getSubmitTime());
        });
        return result;
    }

    @Override
    public TeacherReviewVO getReview(Long instanceId, Long itemProgressId) {
        Long teacherId = UserContext.requireUserId();
        checkInstanceBelongToTeacher(instanceId, teacherId);

        // 组合包:按任务项进度查批阅记录
        LambdaQueryWrapper<MedicalRecordReview> wrapper;
        if (itemProgressId != null) {
            wrapper = new LambdaQueryWrapper<MedicalRecordReview>()
                    .eq(MedicalRecordReview::getAssignmentItemProgressId, itemProgressId);
        } else {
            wrapper = new LambdaQueryWrapper<MedicalRecordReview>()
                    .eq(MedicalRecordReview::getInstanceId, instanceId);
        }
        wrapper.orderByDesc(MedicalRecordReview::getCreatedAt);

        List<MedicalRecordReview> reviews = reviewMapper.selectList(wrapper);
        if (reviews.isEmpty()) {
            return null;
        }
        MedicalRecordReview latest = reviews.get(0);

        // 定位任务项进度，取学生真实大病历正文与格式校验结果
        AssignmentItemProgress progress = findProgress(instanceId, itemProgressId);
        TeacherReviewVO vo = toVO(latest);
        if (itemProgressId != null) {
            vo.setItemProgressId(itemProgressId);
        }
        if (progress != null) {
            vo.setMedicalRecordText(progress.getMedicalRecordText());
            fillFormatShield(vo, progress.getFormatCheckResult());
        } else if (vo.getMedicalRecordText() == null) {
            // 存量实例也尽力回传正文，杜绝前端显示壳数据
            vo.setMedicalRecordText(loadLegacyRecord(instanceId));
        }
        fillDeductions(vo, latest.getMistakesJson());
        fillScoreLevel(vo, latest.getTotalScore());
        return vo;
    }

    /** 按 itemProgressId（组合包）或 instanceId（存量兜底）定位任务项进度 */
    private AssignmentItemProgress findProgress(Long instanceId, Long itemProgressId) {
        if (itemProgressId != null) {
            AssignmentItemProgress p = progressMapper.selectById(itemProgressId);
            if (p != null && instanceId.equals(p.getInstanceId())) {
                return p;
            }
        }
        return progressMapper.selectOne(new LambdaQueryWrapper<AssignmentItemProgress>()
                .eq(AssignmentItemProgress::getInstanceId, instanceId)
                .orderByDesc(AssignmentItemProgress::getCreatedAt)
                .last("LIMIT 1"));
    }

    /** 存量实例（无任务项进度）：兼容历史病历字段，找不到则返回 null */
    private String loadLegacyRecord(Long instanceId) {
        try {
            AssignmentItemProgress p = progressMapper.selectOne(
                    new LambdaQueryWrapper<AssignmentItemProgress>()
                            .eq(AssignmentItemProgress::getInstanceId, instanceId)
                            .last("LIMIT 1"));
            return p == null ? null : p.getMedicalRecordText();
        } catch (Exception e) {
            return null;
        }
    }

    /** 解析格式校验 JSON，填充 passed 与明细 */
    private void fillFormatShield(TeacherReviewVO vo, String formatCheckResult) {
        if (isBlank(formatCheckResult)) {
            return;
        }
        try {
            var node = objectMapper.readTree(formatCheckResult);
            boolean passed = node.path("passed").asBoolean(false);
            List<String> errors = new java.util.ArrayList<>();
            if (node.has("errors") && node.get("errors").isArray()) {
                node.get("errors").forEach(e -> errors.add(e.asText()));
            }
            vo.setFormatShieldPassed(passed);
            vo.setFormatShieldDetail(passed
                    ? "格式校验通过 · 必填段落齐全"
                    : "格式校验未通过：" + errors.stream().filter(Objects::nonNull)
                            .collect(Collectors.joining("；")));
        } catch (Exception e) {
            log.warn("解析格式校验结果失败: {}", e.getMessage());
        }
    }

    /** 将 AI 批阅 mistakes JSON 归一化为前端扣分卡 [{name, description, points}] */
    private void fillDeductions(TeacherReviewVO vo, String mistakesJson) {
        if (isBlank(mistakesJson)) {
            return;
        }
        try {
            var arr = objectMapper.readTree(mistakesJson);
            List<Map<String, Object>> list = new java.util.ArrayList<>();
            if (arr.isArray()) {
                arr.forEach(item -> {
                    String location = item.path("location").asText("");
                    String type = item.path("type").asText("");
                    String comment = item.path("comment").asText("");
                    int deduction = item.path("deduction").asInt(0);
                    if ((isBlank(location) && isBlank(comment)) && deduction == 0) {
                        return;
                    }
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("name", isBlank(location) ? typeLabel(type) : location);
                    map.put("description", comment);
                    map.put("points", "-" + deduction);
                    list.add(map);
                });
            }
            if (!list.isEmpty()) {
                vo.setDeductions(list);
            }
        } catch (Exception e) {
            log.warn("解析扣分明细失败: {}", e.getMessage());
        }
    }

    /** AI 类型码 → 中文标签 */
    private String typeLabel(String type) {
        return switch (type == null ? "" : type) {
            case "format" -> "格式问题";
            case "medical_fact" -> "医学事实";
            case "logic" -> "逻辑推理";
            case "ddx" -> "鉴别诊断";
            case "humanity" -> "人文关怀";
            case "diagnosis" -> "诊断";
            case "history" -> "问诊遗漏";
            case "exam" -> "辅助检查";
            case "record" -> "记录规范";
            case "communication" -> "沟通";
            default -> type;
        };
    }

    /** 按总分分档给出评级文案 */
    /**
     * 主观题错题闭环：教师复核确认成绩（status=5）后，低于阈值的题目收入学生错题本。
     *
     * <p>错题类型固定为 essay，AI 归因走「失分维度」模式（区别于客观题的临床推理分叉）。
     * 幂等：同一学生 + 同一题目只保留一条记录，重复批改只累加次数与刷新证据，不新增。
     */
    private void syncEssayMistake(AssignmentItemProgress progress, AssignmentItem item,
                                  BigDecimal score, String mistakesJson, String reviewComment) {
        if (progress == null || score == null) {
            return;
        }
        Long studentId = progress.getStudentId();
        if (studentId == null) {
            return;
        }
        if (score.doubleValue() >= ESSAY_MISTAKE_SCORE_THRESHOLD) {
            return;
        }
        Long questionId = firstQuestionId(item);
        if (questionId == null) {
            log.info("主观题错题跳过：任务项未关联题目 itemId={}", progress.getItemId());
            return;
        }
        PracticeQuestion q = questionMapper.selectById(questionId);
        String evidence = buildEssayEvidence(score, mistakesJson, reviewComment);
        try {
            StudentMistakes existing = mistakesMapper.selectOne(new LambdaQueryWrapper<StudentMistakes>()
                    .eq(StudentMistakes::getStudentId, studentId)
                    .eq(StudentMistakes::getQuestionId, questionId)
                    .eq(StudentMistakes::getMistakeType, StudentMistakeServiceImpl.SUBJECTIVE_TYPE)
                    .last("LIMIT 1"));
            if (existing != null) {
                StudentMistakes upd = new StudentMistakes();
                upd.setId(existing.getId());
                upd.setWrongCount((existing.getWrongCount() == null ? 0 : existing.getWrongCount()) + 1);
                upd.setResolvedStatus(0);
                upd.setConsecutiveCorrect(0);
                upd.setEvidenceJson(evidence);
                upd.setAiAnalysisJson(null);
                mistakesMapper.updateById(upd);
                return;
            }
            StudentMistakes m = new StudentMistakes();
            m.setStudentId(studentId);
            m.setQuestionId(questionId);
            m.setCaseId(progress.getCaseId());
            m.setMistakeType(StudentMistakeServiceImpl.SUBJECTIVE_TYPE);
            m.setKnowledgeTag(q == null ? null : q.getKnowledgeTag());
            m.setStudentAnswer(resolveAnswer(progress, questionId));
            m.setStandardAnswer(q == null ? null : firstNonBlank(q.getAnswer(), q.getExplanation()));
            m.setEvidenceJson(evidence);
            m.setResolvedStatus(0);
            m.setConsecutiveCorrect(0);
            m.setWrongCount(1);
            m.setFocusFlag(0);
            mistakesMapper.insert(m);
            mistakeAnalysisTrigger.triggerAfterCommit(m.getId(), studentId);
        } catch (Exception e) {
            log.warn("主观题收入错题本失败（不影响复核）: progressId={} err={}",
                    progress.getId(), e.getMessage());
        }
    }

    /** 取任务项关联的第一个题目 id（组合包多题场景取首题） */
    private Long firstQuestionId(AssignmentItem item) {
        if (item == null || item.getQuestionIds() == null || item.getQuestionIds().isBlank()) {
            return null;
        }
        for (String s : item.getQuestionIds().split("[,，\\s]+")) {
            String t = s.trim();
            if (!t.isEmpty()) {
                try {
                    return Long.parseLong(t);
                } catch (NumberFormatException ignore) {
                    // 非数字片段跳过
                }
            }
        }
        return null;
    }

    /** 主观题证据：把得分与批阅明细拼成 AI 归因可读的文本（避免新增表字段） */
    private String buildEssayEvidence(BigDecimal score, String mistakesJson, String reviewComment) {
        StringBuilder sb = new StringBuilder();
        sb.append("得分：").append(score).append("/100");
        if (mistakesJson != null && !mistakesJson.isBlank()) {
            sb.append("\n批阅错误明细：")
                    .append(mistakesJson.length() > 500 ? mistakesJson.substring(0, 500) : mistakesJson);
        }
        if (reviewComment != null && !reviewComment.isBlank()) {
            sb.append("\n评语：").append(reviewComment);
        }
        return sb.toString();
    }

    private String firstNonBlank(String a, String b) {
        return a != null && !a.isBlank() ? a : b;
    }

    private void fillScoreLevel(TeacherReviewVO vo, BigDecimal score) {
        if (score == null) {
            return;
        }
        int s = score.intValue();
        String level;
        if (s >= 90) {
            level = "优秀";
        } else if (s >= 80) {
            level = "良好";
        } else if (s >= 70) {
            level = "中等";
        } else if (s >= 60) {
            level = "及格";
        } else {
            level = "有待加强";
        }
        vo.setAiScoreLevel(level);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long overrideReview(Long instanceId, Long itemProgressId, ReviewOverrideDTO dto) {
        Long teacherId = UserContext.requireUserId();
        AssignmentInstance inst = checkInstanceBelongToTeacher(instanceId, teacherId);

        // 校验被覆盖的 AI 批阅记录存在且属于该实例/任务项
        MedicalRecordReview aiReview = reviewMapper.selectById(dto.getOverrideFromReviewId());
        if (aiReview == null
                || !instanceId.equals(aiReview.getInstanceId())
                || (itemProgressId != null && !itemProgressId.equals(aiReview.getAssignmentItemProgressId()))) {
            throw new BizException(ResultCode.BAD_REQUEST, "被覆盖的AI批阅记录不存在或不属于该实例");
        }

        if (itemProgressId != null) {
            // ---------- 组合包:覆盖任务项进度 ----------
            AssignmentItemProgress progress = progressMapper.selectById(itemProgressId);
            if (progress == null || !instanceId.equals(progress.getInstanceId())) {
                throw new BizException(ResultCode.BAD_REQUEST, "任务项进度不存在或不属于该实例");
            }
            int st = progress.getStatus() == null ? 0 : progress.getStatus();
            if (st != 4) {
                throw new BizException(ResultCode.BAD_REQUEST, "当前任务项状态不支持教师复核，状态=" + st);
            }
            MedicalRecordReview teacherReview = new MedicalRecordReview();
            teacherReview.setInstanceId(instanceId);
            teacherReview.setAssignmentItemProgressId(itemProgressId);
            teacherReview.setReviewerType("TEACHER");
            teacherReview.setTotalScore(dto.getTotalScore());
            teacherReview.setMistakesJson(dto.getMistakesJson());
            teacherReview.setReviewComment(dto.getReviewComment());
            teacherReview.setOverrideFromReviewId(dto.getOverrideFromReviewId());
            teacherReview.setReviewedBy(teacherId);
            reviewMapper.insert(teacherReview);

            progress.setStatus(5);
            progress.setScore(dto.getTotalScore());
            progress.setCompletedAt(java.time.LocalDateTime.now());
            progressMapper.updateById(progress);
            // 主观题闭环：教师复核确认成绩后，低分题收入错题本并异步预生成失分维度归因
            syncEssayMistake(progress, itemMapper.selectById(progress.getItemId()),
                    dto.getTotalScore(), dto.getMistakesJson(), dto.getReviewComment());
            refreshInstanceStatus(inst);

            auditLogService.record(
                    "teacher_review_override",
                    "medical_record_review",
                    teacherReview.getId(),
                    toJson(java.util.Map.of("status", st, "aiReviewId", dto.getOverrideFromReviewId())),
                    toJson(java.util.Map.of("status", 5, "teacherReviewId", teacherReview.getId())));
            log.info("教师{}覆盖任务项{}批阅结果，teacherReviewId={} score={}",
                    teacherId, itemProgressId, teacherReview.getId(), dto.getTotalScore());
            return teacherReview.getId();
        }

        // ---------- 存量:覆盖作业实例 ----------
        int status = inst.getStatus() == null ? 0 : inst.getStatus();
        // 仅"待复核(4)"状态允许教师覆盖；已完成(5)如需二次修改可由管理员介入
        if (status != 4) {
            throw new BizException(ResultCode.BAD_REQUEST, "当前实例状态不支持教师复核，状态=" + status);
        }

        // 写入教师批阅记录
        MedicalRecordReview teacherReview = new MedicalRecordReview();
        teacherReview.setInstanceId(instanceId);
        teacherReview.setReviewerType("TEACHER");
        teacherReview.setTotalScore(dto.getTotalScore());
        teacherReview.setMistakesJson(dto.getMistakesJson());
        teacherReview.setReviewComment(dto.getReviewComment());
        teacherReview.setOverrideFromReviewId(dto.getOverrideFromReviewId());
        teacherReview.setReviewedBy(teacherId);
        reviewMapper.insert(teacherReview);

        // 实例状态 -> 已完成
        inst.setStatus(5);
        instanceMapper.updateById(inst);

        // 审计日志
        Map<String, Object> before = new HashMap<>();
        before.put("status", status);
        before.put("aiReviewId", dto.getOverrideFromReviewId());
        Map<String, Object> after = new HashMap<>();
        after.put("status", 5);
        after.put("teacherReviewId", teacherReview.getId());
        after.put("totalScore", dto.getTotalScore());
        auditLogService.record(
                "teacher_review_override",
                "medical_record_review",
                teacherReview.getId(),
                toJson(before),
                toJson(after));

        log.info("教师{}覆盖实例{}批阅结果，teacherReviewId={} score={}",
                teacherId, instanceId, teacherReview.getId(), dto.getTotalScore());
        return teacherReview.getId();
    }

    /** 聚合刷新作业实例状态(组合包):全部任务项完成=5 */
    private void refreshInstanceStatus(AssignmentInstance inst) {
        List<AssignmentItemProgress> ps = progressMapper.selectList(
                new LambdaQueryWrapper<AssignmentItemProgress>()
                        .eq(AssignmentItemProgress::getInstanceId, inst.getId()));
        if (ps.isEmpty()) return;
        boolean allDone = ps.stream().allMatch(p -> p.getStatus() != null && p.getStatus() == 5);
        boolean anyActive = ps.stream().anyMatch(p -> p.getStatus() != null && p.getStatus() > 0);
        inst.setStatus(allDone ? 5 : (anyActive ? 1 : 0));
        List<java.math.BigDecimal> scores = ps.stream().map(p -> p.getScore())
                .filter(Objects::nonNull).toList();
        if (!scores.isEmpty()) {
            double avg = scores.stream().mapToDouble(java.math.BigDecimal::doubleValue).average().orElse(0);
            inst.setScore(java.math.BigDecimal.valueOf(Math.round(avg * 10) / 10.0));
        }
        instanceMapper.updateById(inst);
    }

    /** 作业→第一个目标班级 + 班级名映射 */
    private Map<Long, String> loadClassNameMap(Map<Long, Assignment> assignmentMap,
                                               Map<Long, Long> firstClassByAssignment) {
        Map<Long, String> classNameById = new HashMap<>();
        if (assignmentMap.isEmpty()) return classNameById;
        List<AssignmentTargetClass> targets = targetClassMapper.selectList(
                new LambdaQueryWrapper<AssignmentTargetClass>()
                        .in(AssignmentTargetClass::getAssignmentId, assignmentMap.keySet()));
        Map<Long, AssignmentTargetClass> firstByAssignment = new HashMap<>();
        targets.forEach(t -> firstByAssignment.putIfAbsent(t.getAssignmentId(), t));
        List<Long> classIds = targets.stream().map(AssignmentTargetClass::getClassId)
                .filter(Objects::nonNull).distinct().toList();
        if (!classIds.isEmpty()) {
            classMapper.selectBatchIds(classIds).forEach(c -> classNameById.put(c.getId(), c.getName()));
        }
        firstByAssignment.forEach((aid, t) -> firstClassByAssignment.put(aid, t.getClassId()));
        return classNameById;
    }

    private Map<Long, String> loadCaseTitles(List<AssignmentItem> items) {
        List<Long> ids = items.stream().map(AssignmentItem::getCaseId)
                .filter(Objects::nonNull).distinct().toList();
        Map<Long, String> map = new HashMap<>();
        if (!ids.isEmpty()) {
            for (SpCaseConfig c : caseMapper.selectList(
                    new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, ids))) {
                map.put(c.getId(), c.getTitle());
            }
        }
        return map;
    }

    /** 每任务项进度最新一条批阅记录 */
    private Map<Long, MedicalRecordReview> loadLatestReviewByProgress(List<AssignmentItemProgress> progresses) {
        List<Long> progressIds = progresses.stream().map(AssignmentItemProgress::getId).toList();
        Map<Long, MedicalRecordReview> map = new HashMap<>();
        if (progressIds.isEmpty()) return map;
        reviewMapper.selectList(new LambdaQueryWrapper<MedicalRecordReview>()
                        .in(MedicalRecordReview::getAssignmentItemProgressId, progressIds)
                        .orderByDesc(MedicalRecordReview::getCreatedAt))
                .forEach(r -> map.putIfAbsent(r.getAssignmentItemProgressId(), r));
        return map;
    }

    /**
     * 校验实例存在、属于当前教师布置的作业
     */
    private AssignmentInstance checkInstanceBelongToTeacher(Long instanceId, Long teacherId) {
        AssignmentInstance inst = instanceMapper.selectById(instanceId);
        if (inst == null) {
            throw new BizException(ResultCode.INSTANCE_NOT_FOUND);
        }
        Assignment a = assignmentMapper.selectById(inst.getAssignmentId());
        if (a == null) {
            throw new BizException(ResultCode.ASSIGNMENT_NOT_FOUND);
        }
        if (!teacherId.equals(a.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能复核本人布置作业的实例");
        }
        return inst;
    }

    private TeacherReviewVO toVO(MedicalRecordReview r) {
        return TeacherReviewVO.builder()
                .reviewId(r.getId())
                .instanceId(r.getInstanceId())
                .reviewerType(r.getReviewerType())
                .totalScore(r.getTotalScore())
                .mistakesJson(r.getMistakesJson())
                .reviewComment(r.getReviewComment())
                .overrideFromReviewId(r.getOverrideFromReviewId())
                .reviewedBy(r.getReviewedBy())
                .createdAt(r.getCreatedAt())
                .updatedAt(r.getUpdatedAt())
                .build();
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    /** 是否为需人工复核的主观题（简答/论述） */
    private boolean isSubjective(String type) {
        return type != null
                && ("essay".equalsIgnoreCase(type)
                    || "short_answer".equalsIgnoreCase(type)
                    || "subjective".equalsIgnoreCase(type));
    }

    private List<Long> parseQuestionIds(String json) {
        if (isBlank(json)) {
            return List.of();
        }
        try {
            return objectMapper.readValue(json, objectMapper.getTypeFactory()
                    .constructCollectionType(List.class, Long.class));
        } catch (Exception e) {
            log.warn("解析题目ID列表失败: error={}", e.getMessage());
            return List.of();
        }
    }

    /** 从任务项进度的学生答案 JSON 中取出指定题目的作答文本 */
    private String resolveAnswer(AssignmentItemProgress progress, Long questionId) {
        if (progress == null || questionId == null || isBlank(progress.getAnswersJson())) {
            return null;
        }
        try {
            var root = objectMapper.readTree(progress.getAnswersJson());
            var entry = root.get(String.valueOf(questionId));
            if (entry == null || !entry.isObject()) {
                return null;
            }
            var ans = entry.get("answer");
            return ans == null || !ans.isTextual() ? null : ans.asText();
        } catch (Exception e) {
            return null;
        }
    }

    /** 将 AI 主观题批阅的维度/错误明细归档到 mistakes_json，供后续复核留痕 */
    private String buildEssayMistakesJson(Map<String, Object> result) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("dimensions", result.get("dimensions"));
        payload.put("mistakes", result.get("mistakes"));
        return toJson(payload);
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            log.warn("JSON序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
