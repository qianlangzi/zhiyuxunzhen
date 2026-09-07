package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.*;
import com.zhiyu.mapper.*;
import com.zhiyu.service.TeacherAssignmentService;
import com.zhiyu.service.TeacherDashboardService;
import com.zhiyu.service.TeacherLessonService;
import com.zhiyu.service.dto.AssignmentCreateDTO;
import com.zhiyu.service.dto.LessonPlanCreateDTO;
import com.zhiyu.service.dto.LessonPublishDTO;
import com.zhiyu.vo.TeacherDashboardVO;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.apache.poi.xwpf.usermodel.XWPFParagraph;
import org.apache.poi.xwpf.usermodel.XWPFRun;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.FileOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 智能备课服务实现（助教核心）
 * 教案创作台：对话式需求确认 → AI 生成教案 → 编辑 → 关联病例/课件 → 导出分享。
 * 备课是教师自用的教案，不再面向班级发布（发布链路仅保留学生端资料任务的兼容读取）。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherLessonServiceImpl implements TeacherLessonService {

    private final LessonPlanMapper lessonPlanMapper;
    private final LessonMaterialMapper materialMapper;
    private final LessonPublishMapper publishMapper;
    private final StudentAlertMapper alertMapper;
    private final SysNotificationMapper notificationMapper;
    private final SpCaseConfigMapper caseMapper;
    private final TeachingClassMapper classMapper;
    private final SysUserMapper userMapper;
    private final StudentClassMembershipMapper membershipMapper;
    private final LessonTaskProgressMapper lessonTaskProgressMapper;
    private final TextbookMapper textbookMapper;
    private final TeacherAssignmentService assignmentService;
    private final TeacherDashboardService dashboardService;
    private final AiPlatformClient aiPlatformClient;
    private final ObjectMapper objectMapper;

    @Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    @Value("${zhiyu.upload.base-url:/uploads}")
    private String uploadBaseUrl;

    private static final Set<String> ALLOWED_TYPES = Set.of("pdf", "ppt", "pptx", "mp4", "mp3", "image", "png", "jpg", "jpeg");

    // ---------------- 备课包 CRUD ----------------

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long createLesson(LessonPlanCreateDTO req) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = new LessonPlan();
        plan.setTeacherId(teacherId);
        plan.setTitle(req.getTitle());
        plan.setDepartment(req.getDepartment());
        plan.setTargetGrade(req.getTargetGrade());
        plan.setObjectivesJson(req.getObjectives());
        plan.setKeyPointsJson(req.getKeyPoints());
        plan.setCaseId(req.getCaseId());
        plan.setCaseSource(req.getCaseSource() == null ? 0 : req.getCaseSource());
        plan.setStatus(0);
        lessonPlanMapper.insert(plan);
        return plan.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateLesson(Long lessonId, LessonPlanCreateDTO req) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        plan.setTitle(req.getTitle());
        plan.setDepartment(req.getDepartment());
        plan.setTargetGrade(req.getTargetGrade());
        plan.setObjectivesJson(req.getObjectives());
        plan.setKeyPointsJson(req.getKeyPoints());
        if (req.getAiDesign() != null && !req.getAiDesign().isBlank()) {
            plan.setAiDesignJson(req.getAiDesign());
            plan.setStatus(1);
        }
        if (req.getTargetClassId() != null) {
            plan.setTargetClassId(req.getTargetClassId());
        }
        if (req.getTextbookId() != null) {
            plan.setTextbookId(req.getTextbookId());
        }
        if (req.getCaseId() != null) {
            plan.setCaseId(req.getCaseId());
            plan.setCaseSource(req.getCaseSource() == null ? 1 : req.getCaseSource());
        }
        // 教案管理：置顶 / 优先级
        if (req.getIsTop() != null) {
            plan.setIsTop(req.getIsTop());
        }
        if (req.getPriority() != null) {
            plan.setPriority(req.getPriority());
        }
        lessonPlanMapper.updateById(plan);
    }

    @Override
    public List<Map<String, Object>> listLessons() {
        Long teacherId = UserContext.requireUserId();
        List<LessonPlan> plans = lessonPlanMapper.selectList(
                new LambdaQueryWrapper<LessonPlan>()
                        .eq(LessonPlan::getTeacherId, teacherId)
                        .eq(LessonPlan::getIsDeleted, 0));
        // 展示顺序：置顶最前 → 手动拖动序号（0=未排序置后）→ 优先级 → 更新时间
        plans.sort((a, b) -> {
            int at = a.getIsTop() == null ? 0 : a.getIsTop();
            int bt = b.getIsTop() == null ? 0 : b.getIsTop();
            if (at != bt) return bt - at;
            int as = a.getSortOrder() == null ? 0 : a.getSortOrder();
            int bs = b.getSortOrder() == null ? 0 : b.getSortOrder();
            if (as != bs) return (as == 0 ? Integer.MAX_VALUE : as)
                    - (bs == 0 ? Integer.MAX_VALUE : bs);
            int ap = a.getPriority() == null ? 0 : a.getPriority();
            int bp = b.getPriority() == null ? 0 : b.getPriority();
            if (ap != bp) return bp - ap;
            LocalDateTime au = a.getUpdatedAt(), bu = b.getUpdatedAt();
            if (au == null && bu == null) return 0;
            if (au == null) return 1;
            if (bu == null) return -1;
            return bu.compareTo(au);
        });
        List<LessonPlan> all = plans;
        Map<Long, Long> materialCounts = new HashMap<>();
        if (!all.isEmpty()) {
            List<LessonMaterial> mats = materialMapper.selectList(
                    new LambdaQueryWrapper<LessonMaterial>().in(LessonMaterial::getLessonId,
                            all.stream().map(LessonPlan::getId).toList()));
            materialCounts = mats.stream().collect(Collectors.groupingBy(
                    LessonMaterial::getLessonId, Collectors.counting()));
        }
        Map<Long, Long> counts = materialCounts;
        return all.stream().map(p -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", p.getId());
            m.put("title", p.getTitle());
            m.put("department", p.getDepartment());
            m.put("targetGrade", p.getTargetGrade());
            m.put("caseId", p.getCaseId());
            m.put("caseSource", p.getCaseSource());
            m.put("status", p.getStatus());
            m.put("isTop", p.getIsTop() == null ? 0 : p.getIsTop());
            m.put("priority", p.getPriority() == null ? 0 : p.getPriority());
            m.put("materialCount", counts.getOrDefault(p.getId(), 0L));
            m.put("createdAt", p.getCreatedAt());
            return m;
        }).toList();
    }

    @Override
    public Map<String, Object> lessonDetail(Long lessonId) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        List<LessonMaterial> materials = materialMapper.selectList(
                new LambdaQueryWrapper<LessonMaterial>()
                        .eq(LessonMaterial::getLessonId, lessonId)
                        .orderByDesc(LessonMaterial::getCreatedAt));

        Map<String, Object> detail = new HashMap<>();
        detail.put("id", plan.getId());
        detail.put("title", plan.getTitle());
        detail.put("department", plan.getDepartment());
        detail.put("targetGrade", plan.getTargetGrade());
        detail.put("objectives", plan.getObjectivesJson());
        detail.put("keyPoints", plan.getKeyPointsJson());
        detail.put("aiDesign", plan.getAiDesignJson());
        detail.put("pptOutline", plan.getPptOutlineJson());
        detail.put("caseId", plan.getCaseId());
        detail.put("caseSource", plan.getCaseSource());
        detail.put("status", plan.getStatus());

        // 关联病例摘要（若有）
        if (plan.getCaseId() != null) {
            SpCaseConfig c = caseMapper.selectById(plan.getCaseId());
            if (c != null) {
                Map<String, Object> caseInfo = new HashMap<>();
                caseInfo.put("id", c.getId());
                caseInfo.put("title", c.getTitle());
                caseInfo.put("department", c.getDepartment());
                caseInfo.put("difficulty", c.getDifficulty());
                caseInfo.put("knowledgeTags", c.getKnowledgeTags());
                detail.put("case", caseInfo);
            }
        }

        detail.put("materials", materials.stream().map(m -> {
            Map<String, Object> mm = new HashMap<>();
            mm.put("id", m.getId());
            mm.put("materialType", m.getMaterialType());
            mm.put("title", m.getTitle());
            mm.put("fileUrl", m.getFileUrl());
            mm.put("knowledgeTags", m.getKnowledgeTags());
            mm.put("durationSec", m.getDurationSec());
            mm.put("createdAt", m.getCreatedAt());
            return mm;
        }).toList());
        return detail;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void deleteLesson(Long lessonId) {
        Long teacherId = UserContext.requireUserId();
        requireOwnLesson(lessonId, teacherId);
        // @TableLogic 字段不进 updateById 的 SET，必须走 deleteById 触发逻辑删除
        lessonPlanMapper.deleteById(lessonId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchDeleteLessons(List<Long> lessonIds) {
        if (lessonIds == null || lessonIds.isEmpty()) {
            return;
        }
        Long teacherId = UserContext.requireUserId();
        List<LessonPlan> own = lessonPlanMapper.selectList(
                new LambdaQueryWrapper<LessonPlan>()
                        .in(LessonPlan::getId, lessonIds)
                        .eq(LessonPlan::getTeacherId, teacherId));
        for (LessonPlan p : own) {
            lessonPlanMapper.deleteById(p.getId());
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void sortLessons(List<Long> lessonIds) {
        Long teacherId = UserContext.requireUserId();
        if (lessonIds == null || lessonIds.isEmpty()) {
            return;
        }
        // 只允许排序本人创建的教案，未传入的教案保持原序号不动
        Set<Long> mine = new HashSet<>(lessonPlanMapper.selectList(
                new LambdaQueryWrapper<LessonPlan>()
                        .eq(LessonPlan::getTeacherId, teacherId))
                .stream()
                .map(LessonPlan::getId)
                .toList());
        int rank = 1;
        for (Long id : lessonIds) {
            if (id == null || !mine.contains(id)) continue;
            LessonPlan p = lessonPlanMapper.selectById(id);
            if (p == null) continue;
            p.setSortOrder(rank++);
            lessonPlanMapper.updateById(p);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long mergeLessons(List<Long> lessonIds, String title) {
        if (lessonIds == null || lessonIds.size() < 2) {
            throw new BizException(ResultCode.BAD_REQUEST, "合并至少需要选择 2 个教案");
        }
        Long teacherId = UserContext.requireUserId();
        List<LessonPlan> own = new ArrayList<>(lessonPlanMapper.selectList(
                new LambdaQueryWrapper<LessonPlan>()
                        .in(LessonPlan::getId, lessonIds)
                        .eq(LessonPlan::getTeacherId, teacherId)
                        .eq(LessonPlan::getIsDeleted, 0)));
        if (own.size() < 2) {
            throw new BizException(ResultCode.NOT_FOUND, "教案不存在或已删除");
        }

        // 按优先级合并：置顶优先、优先级数值大者在前，数值相同按 id 升序稳定排序；
        // 优先级最高的一份作为合并基础载体（标题/科室/年级/病例/教材/教学设计均以其为准）。
        own.sort(Comparator.comparing(LessonPlan::getIsTop,
                        Comparator.nullsLast(Comparator.reverseOrder()))
                .thenComparing(LessonPlan::getPriority,
                        Comparator.nullsLast(Comparator.reverseOrder()))
                .thenComparing(LessonPlan::getId));
        LessonPlan base = own.get(0);

        // 教学目标 / 重难点：以基础教案内容为基础，去重拼接其余教案的内容（仅作规则兜底）
        List<String> goals = new ArrayList<>(jsonStringList(base.getObjectivesJson()));
        List<String> keys = new ArrayList<>(jsonStringList(base.getKeyPointsJson()));
        final List<String> ruleGoals = goals;
        final List<String> ruleKeys = keys;
        for (int i = 1; i < own.size(); i++) {
            LessonPlan p = own.get(i);
            jsonStringList(p.getObjectivesJson()).stream()
                    .filter(s -> !ruleGoals.contains(s)).forEach(ruleGoals::add);
            jsonStringList(p.getKeyPointsJson()).stream()
                    .filter(s -> !ruleKeys.contains(s)).forEach(ruleKeys::add);
        }

        // —— AI 合并教学设计：以优先级最高教案为主体，LLM 消解各方冲突 ——
        Map<String, Object> aiMerged = null;
        List<Map<String, Object>> designs = new ArrayList<>();
        for (LessonPlan p : own) {
            Map<String, Object> d = parseDesign(p.getAiDesignJson());
            if (d.isEmpty()) {
                // 无 AI 设计结果（草稿）：用标题/目标/重难点组装最小骨架，
                // 保证 AI 合并至少能拿到 ≥2 份输入，草稿内容也可被纳入合并结果
                d = new HashMap<>();
                d.put("title", blank(p.getTitle()));
                d.put("department", blank(p.getDepartment()));
                d.put("targetGrade", blank(p.getTargetGrade()));
                List<String> draftGoals = jsonStringList(p.getObjectivesJson());
                if (!draftGoals.isEmpty()) d.put("teachingObjectives", draftGoals);
                List<String> kps = jsonStringList(p.getKeyPointsJson());
                if (!kps.isEmpty()) d.put("keyPoints", kps);
                d.put("note", "该教案尚未生成 AI 教学设计，仅提供标题/目标/重难点，请在其基础上整合");
            }
            designs.add(d);
        }
        if (designs.size() >= 2) {
            aiMerged = aiPlatformClient.lessonMerge(
                    title, base.getDepartment(), base.getTargetGrade(), 45, designs);
        }
        // AI 成功：用其结果覆盖教学设计，并同步教学目标/重难点
        if (aiMerged != null && !aiMerged.isEmpty()) {
            try {
                base.setAiDesignJson(objectMapper.writeValueAsString(aiMerged));
            } catch (Exception e) {
                log.warn("合并教案序列化 AI 结果失败: {}", e.getMessage());
            }
            List<String> aiGoals = asStringList(aiMerged.get("teachingObjectives"));
            if (!aiGoals.isEmpty()) goals = aiGoals;
            List<String> mergedKeys = new ArrayList<>(asStringList(aiMerged.get("keyPoints")));
            for (String d : asStringList(aiMerged.get("keyDifficultPoints"))) {
                if (!mergedKeys.contains(d)) mergedKeys.add(d);
            }
            if (!mergedKeys.isEmpty()) keys = mergedKeys;
        } else {
            // AI 不可用或失败：教学设计取优先级最高的基础教案；为空则取第一个非空教案
            if (base.getAiDesignJson() == null || base.getAiDesignJson().isBlank()) {
                own.stream().map(LessonPlan::getAiDesignJson)
                        .filter(s -> s != null && !s.isBlank())
                        .findFirst()
                        .ifPresent(base::setAiDesignJson);
            }
        }

        if (title != null && !title.isBlank()) {
            base.setTitle(title);
        }
        try {
            base.setObjectivesJson(objectMapper.writeValueAsString(goals));
            base.setKeyPointsJson(objectMapper.writeValueAsString(keys));
        } catch (Exception e) {
            log.warn("合并教案目标序列化失败: {}", e.getMessage());
        }
        lessonPlanMapper.updateById(base);

        // 合并后清理被吸收的原始教案（逻辑删除），避免列表残留原有的备课
        for (int i = 1; i < own.size(); i++) {
            lessonPlanMapper.deleteById(own.get(i).getId());
        }
        return base.getId();
    }

    // ---------------- AI 教学设计 ----------------

    @Override
    public Map<String, Object> generateDesign(Long lessonId) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        SpCaseConfig c = plan.getCaseId() == null ? null : caseMapper.selectById(plan.getCaseId());

        String caseContext = "";
        if (c != null) {
            try {
                Map<String, Object> ctx = new HashMap<>();
                ctx.put("title", c.getTitle());
                ctx.put("hiddenDisease", c.getHiddenDisease());
                ctx.put("standardPath", c.getStandardPathJson());
                ctx.put("presetExams", c.getPresetExams());
                ctx.put("knowledgeTags", c.getKnowledgeTags());
                caseContext = objectMapper.writeValueAsString(ctx);
            } catch (Exception e) {
                log.warn("备课设计 caseContext 序列化失败: {}", e.getMessage());
            }
        }

        // 对话确认的备课要素（主题/教材/学情/课时/重难点）
        Map<String, Object> elements = parseElements(plan.getTeachingElementsJson());

        // 教学目标：优先取对话要素 emphasis 拆解，其次 objectivesJson，最后空
        List<String> goals = new ArrayList<>();
        try {
            if (plan.getObjectivesJson() != null && !plan.getObjectivesJson().isBlank()) {
                goals.addAll(objectMapper.readValue(plan.getObjectivesJson(),
                        objectMapper.getTypeFactory().constructCollectionType(List.class, String.class)));
            }
        } catch (Exception e) {
            log.warn("解析教学目标失败: {}", e.getMessage());
        }
        if (goals.isEmpty() && elements.get("emphasis") != null) {
            goals.add(String.valueOf(elements.get("emphasis")));
        }

        // 学情数据（目标班级真实学情，防幻觉依据）
        String studentProfile = buildStudentProfile(teacherId, plan.getTargetClassId());
        // 教材引用（对话确认的教材 / textbook_id）
        List<Map<String, Object>> textbookRefs = buildTextbookRefs(plan, elements);
        // 课时
        Integer duration = parseIntOr(elements.get("duration"), 45);
        // 备课包多模态素材：传给 AI 侧，图片走 VLM 识别、课件作参考锚点
        List<Map<String, Object>> materialRefs = materialMapper.selectList(
                        new LambdaQueryWrapper<LessonMaterial>()
                                .eq(LessonMaterial::getLessonId, lessonId))
                .stream()
                .map(m -> {
                    Map<String, Object> mm = new HashMap<>();
                    mm.put("title", m.getTitle());
                    mm.put("materialType", m.getMaterialType());
                    mm.put("fileUrl", m.getFileUrl());
                    return mm;
                })
                .collect(Collectors.toList());

        Map<String, Object> design = aiPlatformClient.lessonDesign(
                plan.getTitle(), plan.getDepartment(), plan.getTargetGrade(), goals,
                caseContext, textbookRefs, studentProfile, duration, materialRefs);
        if (design != null) {
            try {
                plan.setAiDesignJson(objectMapper.writeValueAsString(design));
                plan.setStatus(1);
                lessonPlanMapper.updateById(plan);
            } catch (Exception e) {
                log.warn("保存教学设计失败: {}", e.getMessage());
            }
        }
        return design;
    }

    @Override
    public Map<String, Object> generatePpt(Long lessonId) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        if (plan.getAiDesignJson() == null || plan.getAiDesignJson().isBlank()) {
            throw new BizException(ResultCode.BAD_REQUEST,
                    "请先点击「AI 生成教案」生成教学设计，再一键生成课件 PPT 提纲");
        }
        String caseContext = "";
        if (plan.getCaseId() != null) {
            SpCaseConfig c = caseMapper.selectById(plan.getCaseId());
            if (c != null) {
                try {
                    Map<String, Object> ctx = new HashMap<>();
                    ctx.put("title", c.getTitle());
                    ctx.put("hiddenDisease", c.getHiddenDisease());
                    ctx.put("standardPath", c.getStandardPathJson());
                    ctx.put("knowledgeTags", c.getKnowledgeTags());
                    caseContext = objectMapper.writeValueAsString(ctx);
                } catch (Exception e) {
                    log.warn("课件 PPT caseContext 序列化失败: {}", e.getMessage());
                }
            }
        }
        Map<String, Object> ppt = aiPlatformClient.lessonPptOutline(
                plan.getTitle(), plan.getDepartment(), plan.getTargetGrade(),
                plan.getAiDesignJson(), caseContext, 12);
        if (ppt != null) {
            try {
                plan.setPptOutlineJson(objectMapper.writeValueAsString(ppt));
                lessonPlanMapper.updateById(plan);
            } catch (Exception e) {
                log.warn("保存课件 PPT 提纲失败: {}", e.getMessage());
            }
        }
        return ppt;
    }

    @Override
    public void savePpt(Long lessonId, Map<String, Object> ppt) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        if (ppt == null) {
            throw new BizException(ResultCode.BAD_REQUEST, "课件提纲内容不能为空");
        }
        try {
            plan.setPptOutlineJson(objectMapper.writeValueAsString(ppt));
            lessonPlanMapper.updateById(plan);
        } catch (Exception e) {
            throw new BizException(ResultCode.INTERNAL_ERROR, "保存课件 PPT 提纲失败：" + e.getMessage());
        }
    }

    // ---------------- 向导式对话引导 ----------------

    @Override
    public Map<String, Object> guide(Long lessonId, String userReply) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        Map<String, Object> elements = parseElements(plan.getTeachingElementsJson());

        Map<String, Object> result = aiPlatformClient.lessonGuide(
                plan.getTitle(), elements, userReply, 0);
        if (result == null) {
            return null;
        }
        // 每轮持久化更新后的已确认要素
        Object confirmedRaw = result.get("confirmed");
        if (confirmedRaw instanceof Map<?, ?> m) {
            try {
                plan.setTeachingElementsJson(objectMapper.writeValueAsString(m));
            } catch (Exception e) {
                log.warn("保存备课要素失败: {}", e.getMessage());
            }
        }
        // 需求确认完成：保存完整需求单并回填标题
        if (Boolean.TRUE.equals(result.get("complete"))) {
            Object summaryRaw = result.get("summary");
            if (summaryRaw instanceof Map<?, ?> m) {
                try {
                    plan.setTeachingElementsJson(objectMapper.writeValueAsString(m));
                } catch (Exception e) {
                    log.warn("保存需求单失败: {}", e.getMessage());
                }
                Object topic = m.get("topic");
                if (topic != null && !String.valueOf(topic).isBlank()) {
                    plan.setTitle(String.valueOf(topic));
                }
            }
            plan.setStatus(1);
        }
        lessonPlanMapper.updateById(plan);
        return result;
    }

    // ---------------- 教案导出（Word + 病例内容 + 附件清单） ----------------

    @Override
    public Map<String, Object> exportDoc(Long lessonId) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        Map<String, Object> design = parseDesign(plan.getAiDesignJson());
        SpCaseConfig c = plan.getCaseId() == null ? null : caseMapper.selectById(plan.getCaseId());
        List<LessonMaterial> materials = materialMapper.selectList(
                new LambdaQueryWrapper<LessonMaterial>()
                        .eq(LessonMaterial::getLessonId, lessonId)
                        .orderByDesc(LessonMaterial::getCreatedAt));

        String fileName = "教案_" + (plan.getTitle() == null ? "未命名" : plan.getTitle()) + ".docx";
        String safeName = fileName.replaceAll("[\\\\/:*?\"<>|\\s]+", "_");
        try {
            Path dir = Paths.get(uploadDir, "exports");
            Files.createDirectories(dir);
            Path target = dir.resolve(safeName);
            try (XWPFDocument doc = new XWPFDocument();
                 FileOutputStream fos = new FileOutputStream(target.toFile())) {
                appendHeading(doc, plan.getTitle() == null ? "未命名教案" : plan.getTitle(), 1);
                appendMeta(doc, plan, design);
                appendSection(doc, "一、教学目标", asStringList(design.get("teachingObjectives")));
                appendSection(doc, "二、教学重点", asStringList(design.get("keyPoints")));
                appendSection(doc, "三、教学难点", asStringList(design.get("keyDifficultPoints")));
                appendOutline(doc, design.get("lessonOutline"));
                appendSection(doc, "四、病例讨论题", asStringList(design.get("caseDiscussion")));
                appendSkillTraining(doc, design.get("skillTraining"));
                appendSection(doc, "五、SP 问诊设计", asStringList(design.get("spInterviewDesign")));
                appendTextSection(doc, "六、板书设计", String.valueOf(design.getOrDefault("boardDesign", "")));
                appendSection(doc, "七、课后作业布置", asStringList(design.get("homeworkSuggestions")));
                appendTextSection(doc, "八、教学反思", String.valueOf(design.getOrDefault("teachingReflection", "")));
                appendRefs(doc, design.get("textbookRefs"), design.get("studentProfileNote"));
                if (c != null) {
                    appendCase(doc, c);
                }
                appendMaterials(doc, materials);
                // Apache POI 的 XWPFDocument 不会自动写出，必须显式写入字节流，
                // 否则生成的文件为 0 字节空文件。
                doc.write(fos);
            }
            String url = uploadBaseUrl + "/exports/" + safeName;
            return Map.of("url", url, "filename", safeName);
        } catch (Exception e) {
            log.error("教案导出失败: lessonId={} error={}", lessonId, e.getMessage(), e);
            throw new BizException(ResultCode.FILE_UPLOAD_ERROR, "教案导出失败：" + e.getMessage());
        }
    }

    // ========= 导出辅助 =========

    private void appendHeading(XWPFDocument doc, String text, int level) {
        XWPFParagraph p = doc.createParagraph();
        p.setSpacingAfter(120);
        XWPFRun run = p.createRun();
        run.setText(text);
        run.setBold(true);
        run.setFontSize(level == 1 ? 18 : 14);
        run.setFontFamily("宋体");
    }

    private void appendMeta(XWPFDocument doc, LessonPlan plan, Map<String, Object> design) {
        XWPFParagraph p = doc.createParagraph();
        p.setSpacingAfter(200);
        XWPFRun run = p.createRun();
        StringBuilder meta = new StringBuilder();
        meta.append("科室：").append(blank(plan.getDepartment())).append("　");
        meta.append("适用年级：").append(blank(plan.getTargetGrade())).append("\n");
        Map<String, Object> elements = parseElements(plan.getTeachingElementsJson());
        if (elements.get("duration") != null) {
            meta.append("课时：").append(elements.get("duration")).append(" 分钟\n");
        }
        if (elements.get("textbook") != null) {
            meta.append("教材：").append(elements.get("textbook")).append("\n");
        }
        if (elements.get("classInfo") != null) {
            meta.append("授课班级/学情：").append(elements.get("classInfo")).append("\n");
        }
        run.setText(meta.toString().trim());
        run.setFontSize(10);
        run.setFontFamily("宋体");
    }

    private void appendSection(XWPFDocument doc, String title, List<String> items) {
        if (items == null || items.isEmpty()) return;
        appendHeading(doc, title, 2);
        for (String it : items) {
            if (it == null || it.isBlank()) continue;
            XWPFParagraph p = doc.createParagraph();
            p.setSpacingAfter(60);
            XWPFRun run = p.createRun();
            run.setText("· " + it);
            run.setFontSize(11);
            run.setFontFamily("宋体");
        }
    }

    private void appendTextSection(XWPFDocument doc, String title, String text) {
        if (text == null || text.isBlank()) return;
        appendHeading(doc, title, 2);
        XWPFParagraph p = doc.createParagraph();
        p.setSpacingAfter(60);
        XWPFRun run = p.createRun();
        run.setText(text);
        run.setFontSize(11);
        run.setFontFamily("宋体");
    }

    private void appendOutline(XWPFDocument doc, Object raw) {
        List<Map<String, Object>> outline = asMapList(raw);
        if (outline.isEmpty()) return;
        appendHeading(doc, "教学过程", 2);
        for (Map<String, Object> step : outline) {
            XWPFParagraph p = doc.createParagraph();
            p.setSpacingAfter(60);
            XWPFRun run = p.createRun();
            run.setText(String.format("%s（%s 分钟）：%s",
                    blank(step.get("phase")), String.valueOf(step.getOrDefault("duration", "")), blank(step.get("content"))));
            run.setFontSize(11);
            run.setFontFamily("宋体");
        }
    }

    private void appendSkillTraining(XWPFDocument doc, Object raw) {
        List<Map<String, Object>> items = asMapList(raw);
        if (items.isEmpty()) return;
        appendHeading(doc, "技能训练环节", 2);
        for (Map<String, Object> it : items) {
            XWPFParagraph p = doc.createParagraph();
            p.setSpacingAfter(60);
            XWPFRun run = p.createRun();
            run.setText(String.format("· %s（%s 分钟）%s",
                    blank(it.get("name")), String.valueOf(it.getOrDefault("duration", "")), blank(it.get("description"))));
            run.setFontSize(11);
            run.setFontFamily("宋体");
        }
    }

    private void appendRefs(XWPFDocument doc, Object refsRaw, Object noteRaw) {
        List<Map<String, Object>> refs = asMapList(refsRaw);
        if (!refs.isEmpty()) {
            appendHeading(doc, "教材出处", 2);
            for (Map<String, Object> r : refs) {
                XWPFParagraph p = doc.createParagraph();
                p.setSpacingAfter(40);
                XWPFRun run = p.createRun();
                run.setText(String.format("· 《%s》%s%s",
                        blank(r.get("book_name")),
                        r.get("chapter") == null ? "" : "·" + r.get("chapter"),
                        r.get("page_number") == null ? "" : "·P" + r.get("page_number")));
                run.setFontSize(10);
                run.setFontFamily("宋体");
            }
        }
        if (noteRaw != null && !String.valueOf(noteRaw).isBlank()) {
            XWPFParagraph p = doc.createParagraph();
            p.setSpacingBefore(80);
            XWPFRun run = p.createRun();
            run.setText("学情说明：" + noteRaw);
            run.setFontSize(10);
            run.setItalic(true);
            run.setFontFamily("宋体");
        }
    }

    private void appendCase(XWPFDocument doc, SpCaseConfig c) {
        appendHeading(doc, "关联病例：" + (c.getTitle() == null ? "" : c.getTitle()), 2);
        appendKeyValue(doc, "科室", c.getDepartment());
        appendKeyValue(doc, "患者资料/主诉与现病史", c.getPatientProfile());
        appendKeyValue(doc, "隐藏疾病", c.getHiddenDisease());
        appendKeyValue(doc, "标准诊疗路径", c.getStandardPathJson());
        appendKeyValue(doc, "预设检查", c.getPresetExams());
        appendKeyValue(doc, "评分要点", c.getScoringPointsJson());
        appendKeyValue(doc, "参考解析", c.getReferenceAnswer());
    }

    private void appendKeyValue(XWPFDocument doc, String label, String value) {
        if (value == null || value.isBlank()) return;
        XWPFParagraph p = doc.createParagraph();
        p.setSpacingAfter(40);
        XWPFRun run = p.createRun();
        run.setText(label + "：" + value);
        run.setFontSize(10.5);
        run.setFontFamily("宋体");
    }

    private void appendMaterials(XWPFDocument doc, List<LessonMaterial> materials) {
        if (materials.isEmpty()) return;
        appendHeading(doc, "附件（课件资料）", 2);
        for (LessonMaterial m : materials) {
            XWPFParagraph p = doc.createParagraph();
            p.setSpacingAfter(40);
            XWPFRun run = p.createRun();
            run.setText("· " + blank(m.getTitle()) + "（" + blank(m.getMaterialType()) + "）");
            run.setFontSize(10.5);
            run.setFontFamily("宋体");
        }
    }

    // ========= 通用辅助 =========

    /** 解析对话确认的备课要素 JSON */
    @SuppressWarnings("unchecked")
    private Map<String, Object> parseElements(String json) {
        if (json == null || json.isBlank()) return new HashMap<>();
        try {
            return objectMapper.readValue(json, Map.class);
        } catch (Exception e) {
            log.warn("解析备课要素失败: {}", e.getMessage());
            return new HashMap<>();
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseDesign(String json) {
        if (json == null || json.isBlank()) return new HashMap<>();
        try {
            return objectMapper.readValue(json, Map.class);
        } catch (Exception e) {
            log.warn("解析教案失败: {}", e.getMessage());
            return new HashMap<>();
        }
    }

    /** 解析存为 JSON 数组字符串的字符串列表（教学目标/重难点），失败或空返回空列表 */
    private List<String> jsonStringList(String json) {
        if (json == null || json.isBlank()) return List.of();
        try {
            List<String> list = objectMapper.readValue(json,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, String.class));
            return list == null ? List.of() : list.stream().filter(s -> s != null && !s.isBlank()).collect(Collectors.toList());
        } catch (Exception e) {
            log.warn("解析 JSON 字符串列表失败: {}", e.getMessage());
            return List.of();
        }
    }

    /** 目标班级真实学情（防幻觉：仅组装系统已有数据） */
    private String buildStudentProfile(Long teacherId, Long targetClassId) {
        if (targetClassId == null) return "";
        try {
            TeachingClass clazz = classMapper.selectById(targetClassId);
            TeacherDashboardVO overview = dashboardService.getOverview(teacherId, targetClassId);
            Map<String, Object> profile = new LinkedHashMap<>();
            profile.put("className", clazz == null ? null : clazz.getName());
            profile.put("completionRate", overview == null ? null : overview.getCompletionRate());
            profile.put("avgOsceScore", overview == null ? null : overview.getAvgOsceScore());
            profile.put("osceDimensionScores", overview == null ? null : overview.getOsceDimensionScores());
            profile.put("commonMistakes", overview == null ? null : overview.getCommonMistakes());
            profile.put("pendingReview", overview == null ? null : overview.getPendingReview());
            return objectMapper.writeValueAsString(profile);
        } catch (Exception e) {
            log.warn("组装学情数据失败: {}", e.getMessage());
            return "";
        }
    }

    /** 教材引用：优先对话确认的教材文本，其次 textbook_id 对应教材 */
    private List<Map<String, Object>> buildTextbookRefs(LessonPlan plan, Map<String, Object> elements) {
        List<Map<String, Object>> refs = new ArrayList<>();
        if (elements.get("textbook") != null) {
            Map<String, Object> ref = new HashMap<>();
            ref.put("book_name", String.valueOf(elements.get("textbook")));
            refs.add(ref);
        }
        if (plan.getTextbookId() != null) {
            com.zhiyu.entity.Textbook t = textbookMapper.selectById(plan.getTextbookId());
            if (t != null) {
                Map<String, Object> ref = new HashMap<>();
                ref.put("book_name", t.getTitle());
                refs.add(ref);
            }
        }
        return refs;
    }

    private Integer parseIntOr(Object v, int def) {
        if (v == null) return def;
        try {
            return Integer.parseInt(String.valueOf(v).replaceAll("[^0-9]", ""));
        } catch (Exception e) {
            return def;
        }
    }

    private List<String> asStringList(Object raw) {
        if (!(raw instanceof List<?> list)) return List.of();
        return list.stream().map(String::valueOf).collect(Collectors.toList());
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> asMapList(Object raw) {
        if (!(raw instanceof List<?> list)) return List.of();
        return list.stream().filter(e -> e instanceof Map)
                .map(e -> (Map<String, Object>) e).collect(Collectors.toList());
    }

    private String blank(Object v) {
        return v == null ? "" : String.valueOf(v);
    }

    // ---------------- 课件资料 ----------------

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long addMaterial(Long lessonId, String materialType, String title,
                            String knowledgeTags, Integer durationSec, MultipartFile file) {
        Long teacherId = UserContext.requireUserId();
        requireOwnLesson(lessonId, teacherId);
        if (file == null || file.isEmpty()) {
            throw new BizException(ResultCode.BAD_REQUEST, "文件不能为空");
        }
        String type = (materialType == null || materialType.isBlank()) ? guessType(file.getOriginalFilename()) : materialType.toLowerCase();
        if (!ALLOWED_TYPES.contains(type)) {
            throw new BizException(ResultCode.BAD_REQUEST, "不支持的文件类型: " + type + "（支持 pdf/ppt/mp4/mp3/图片）");
        }
        // 存储文件
        String stored = storeFile(file, "materials");
        String url = uploadBaseUrl + "/materials/" + stored;

        LessonMaterial m = new LessonMaterial();
        m.setLessonId(lessonId);
        m.setMaterialType(type);
        m.setTitle(title == null || title.isBlank() ? file.getOriginalFilename() : title);
        m.setFileUrl(url);
        m.setObjectKey("materials/" + stored);
        m.setKnowledgeTags(knowledgeTags);
        m.setDurationSec(durationSec);
        materialMapper.insert(m);
        return m.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void removeMaterial(Long lessonId, Long materialId) {
        Long teacherId = UserContext.requireUserId();
        requireOwnLesson(lessonId, teacherId);
        LessonMaterial m = materialMapper.selectById(materialId);
        if (m == null || !lessonId.equals(m.getLessonId())) {
            throw new BizException(ResultCode.NOT_FOUND, "资料不存在");
        }
        materialMapper.deleteById(m.getId());
    }

    // ---------------- 发布闭环 ----------------

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void publish(Long lessonId, LessonPublishDTO req) {
        Long teacherId = UserContext.requireUserId();
        LessonPlan plan = requireOwnLesson(lessonId, teacherId);
        boolean materialOnly = req.getMaterialOnly() != null && req.getMaterialOnly();
        Long assignmentId = null;

        if (!materialOnly) {
            if (plan.getCaseId() == null) {
                throw new BizException(ResultCode.BAD_REQUEST, "备课包尚未关联病例，无法发布病例作业（可改为仅发资料）");
            }
            AssignmentCreateDTO a = new AssignmentCreateDTO();
            a.setTitle(req.getAssignmentTitle() == null || req.getAssignmentTitle().isBlank()
                    ? plan.getTitle() : req.getAssignmentTitle());
            a.setDescription("来自智能备课「" + plan.getTitle() + "」的病例作业");
            a.setDeadline(req.getDeadline());
            a.setClassIds(req.getClassIds());
            AssignmentCreateDTO.Item item = new AssignmentCreateDTO.Item();
            item.setItemType("CASE");
            item.setCaseId(plan.getCaseId());
            item.setRequireMedicalRecord(req.getRequireMedicalRecord());
            a.setItems(java.util.List.of(item));
            assignmentId = assignmentService.create(a);
        }

        for (Long classId : req.getClassIds()) {
            LessonPublish lp = new LessonPublish();
            lp.setLessonId(lessonId);
            lp.setAssignmentId(assignmentId);
            lp.setClassId(classId);
            lp.setMaterialOnly(materialOnly ? 1 : 0);
            lp.setDeadline(req.getDeadline());
            lp.setStatus(0);
            publishMapper.insert(lp);
        }

        // 资料发布到班级后，给班内学生所在的教师（本教师）留站内信确认
        plan.setStatus(1);
        lessonPlanMapper.updateById(plan);
        log.info("教师{}发布备课{}，materialOnly={}，班级{}", teacherId, lessonId, materialOnly, req.getClassIds());
    }

    // ---------------- 学生端学习任务聚合 ----------------

    @Override
    public List<Map<String, Object>> studentTasks() {
        Long studentId = UserContext.requireUserId();
        List<Map<String, Object>> tasks = new ArrayList<>();
        // 学生加入的所有班级（多对多）
        List<Long> classIds = membershipMapper.selectList(
                        new LambdaQueryWrapper<StudentClassMembership>()
                                .eq(StudentClassMembership::getStudentId, studentId))
                .stream()
                .map(StudentClassMembership::getClassId)
                .toList();
        if (classIds.isEmpty()) {
            return tasks;
        }
        // 我已完成的资料发布（completed=true 的不再作为待办展示）
        Set<Long> donePublishIds = new HashSet<>();
        lessonTaskProgressMapper.selectList(new LambdaQueryWrapper<LessonTaskProgress>()
                        .eq(LessonTaskProgress::getStudentId, studentId)
                        .eq(LessonTaskProgress::getStatus, 1))
                .forEach(p -> donePublishIds.add(p.getPublishId()));
        // 班级名（待办页按课程分组需要）
        Map<Long, String> classNameById = new HashMap<>();
        classMapper.selectBatchIds(classIds).forEach(c -> classNameById.put(c.getId(), c.getName()));
        // 1) 备课资料任务（material_only 或带作业的备课均展示资料）
        List<LessonPublish> pubs = publishMapper.selectList(
                new LambdaQueryWrapper<LessonPublish>()
                        .in(LessonPublish::getClassId, classIds)
                        .eq(LessonPublish::getStatus, 0)
                        .orderByDesc(LessonPublish::getCreatedAt));
        for (LessonPublish lp : pubs) {
            LessonPlan plan = lessonPlanMapper.selectById(lp.getLessonId());
            if (plan == null) continue;
            List<LessonMaterial> mats = materialMapper.selectList(
                    new LambdaQueryWrapper<LessonMaterial>()
                            .eq(LessonMaterial::getLessonId, plan.getId()));
            if (lp.getMaterialOnly() == 1 && mats.isEmpty()) continue; // 仅资料但无资料，跳过
            Map<String, Object> t = new HashMap<>();
            t.put("taskType", "lesson");
            t.put("publishId", lp.getId());
            t.put("lessonId", plan.getId());
            t.put("lessonTitle", plan.getTitle());
            t.put("department", plan.getDepartment());
            t.put("materialOnly", lp.getMaterialOnly());
            t.put("deadline", lp.getDeadline());
            t.put("assignmentId", lp.getAssignmentId());
            t.put("caseId", plan.getCaseId());
            t.put("completed", donePublishIds.contains(lp.getId()));
            t.put("classId", lp.getClassId());
            t.put("className", classNameById.getOrDefault(lp.getClassId(), ""));
            t.put("materials", mats.stream().map(m -> {
                Map<String, Object> mm = new HashMap<>();
                mm.put("id", m.getId());
                mm.put("materialType", m.getMaterialType());
                mm.put("title", m.getTitle());
                mm.put("fileUrl", m.getFileUrl());
                mm.put("durationSec", m.getDurationSec());
                return mm;
            }).toList());
            tasks.add(t);
        }
        return tasks;
    }

    @Override
    public Map<String, Object> studentTaskDetail(Long publishId) {
        LessonPublish lp = publishMapper.selectById(publishId);
        if (lp == null) {
            throw new BizException(ResultCode.NOT_FOUND, "学习任务不存在");
        }
        LessonPlan plan = lessonPlanMapper.selectById(lp.getLessonId());
        if (plan == null) {
            throw new BizException(ResultCode.NOT_FOUND, "备课包不存在");
        }
        List<LessonMaterial> mats = materialMapper.selectList(
                new LambdaQueryWrapper<LessonMaterial>()
                        .eq(LessonMaterial::getLessonId, plan.getId()));
        Map<String, Object> detail = new HashMap<>();
        detail.put("publishId", lp.getId());
        detail.put("lessonTitle", plan.getTitle());
        detail.put("department", plan.getDepartment());
        detail.put("targetGrade", plan.getTargetGrade());
        detail.put("objectives", plan.getObjectivesJson());
        detail.put("aiDesign", plan.getAiDesignJson());
        detail.put("materialOnly", lp.getMaterialOnly());
        detail.put("deadline", lp.getDeadline());
        detail.put("assignmentId", lp.getAssignmentId());
        detail.put("caseId", plan.getCaseId());
        // 我是否已标记完成（资料详情页显示完成态）
        Long doneCnt = lessonTaskProgressMapper.selectCount(new LambdaQueryWrapper<LessonTaskProgress>()
                .eq(LessonTaskProgress::getPublishId, publishId)
                .eq(LessonTaskProgress::getStudentId, UserContext.requireUserId())
                .eq(LessonTaskProgress::getStatus, 1));
        detail.put("completed", doneCnt != null && doneCnt > 0);
        detail.put("materials", mats.stream().map(m -> {
            Map<String, Object> mm = new HashMap<>();
            mm.put("id", m.getId());
            mm.put("materialType", m.getMaterialType());
            mm.put("title", m.getTitle());
            mm.put("fileUrl", m.getFileUrl());
            mm.put("knowledgeTags", m.getKnowledgeTags());
            mm.put("durationSec", m.getDurationSec());
            return mm;
        }).toList());
        return detail;
    }

    @Override
    public void completeLessonTask(Long publishId) {
        Long studentId = UserContext.requireUserId();
        LessonPublish lp = publishMapper.selectById(publishId);
        if (lp == null) {
            throw new BizException(ResultCode.NOT_FOUND, "学习任务不存在");
        }
        // 仅班级成员可标记完成
        Long inClass = membershipMapper.selectCount(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getStudentId, studentId)
                .eq(StudentClassMembership::getClassId, lp.getClassId()));
        if (inClass == null || inClass == 0) {
            throw new BizException(ResultCode.FORBIDDEN, "仅班级成员可标记完成");
        }
        LessonTaskProgress exist = lessonTaskProgressMapper.selectOne(
                new LambdaQueryWrapper<LessonTaskProgress>()
                        .eq(LessonTaskProgress::getPublishId, publishId)
                        .eq(LessonTaskProgress::getStudentId, studentId));
        if (exist != null) {
            // 幂等：重复标记直接返回
            if (exist.getStatus() == null || exist.getStatus() != 1) {
                exist.setStatus(1);
                exist.setCompletedAt(LocalDateTime.now());
                lessonTaskProgressMapper.updateById(exist);
            }
            return;
        }
        LessonTaskProgress p = new LessonTaskProgress();
        p.setPublishId(publishId);
        p.setStudentId(studentId);
        p.setStatus(1);
        p.setCompletedAt(LocalDateTime.now());
        lessonTaskProgressMapper.insert(p);
        log.info("学生{}标记资料任务{}完成", studentId, publishId);
    }

    // ---------------- 私有方法 ----------------

    private LessonPlan requireOwnLesson(Long lessonId, Long teacherId) {
        LessonPlan plan = lessonPlanMapper.selectById(lessonId);
        if (plan == null) {
            throw new BizException(ResultCode.NOT_FOUND, "备课包不存在");
        }
        if (!teacherId.equals(plan.getTeacherId())) {
            throw new BizException(ResultCode.FORBIDDEN, "只能操作本人创建的备课包");
        }
        return plan;
    }

    private String guessType(String filename) {
        if (filename == null) return "image";
        String lower = filename.toLowerCase();
        if (lower.endsWith(".pdf")) return "pdf";
        if (lower.endsWith(".ppt") || lower.endsWith(".pptx")) return "ppt";
        if (lower.endsWith(".mp4") || lower.endsWith(".mov")) return "mp4";
        if (lower.endsWith(".mp3") || lower.endsWith(".wav")) return "mp3";
        return "image";
    }

    /** 存储文件到 uploadDir 子目录，返回文件名 */
    private String storeFile(MultipartFile file, String subDir) {
        try {
            Path dir = Paths.get(uploadDir, subDir);
            Files.createDirectories(dir);
            String original = file.getOriginalFilename();
            String ext = "";
            if (original != null && original.contains(".")) {
                ext = original.substring(original.lastIndexOf('.'));
            }
            String filename = UUID.randomUUID().toString().replace("-", "") + ext;
            Path target = dir.resolve(filename);
            file.transferTo(target.toFile());
            return filename;
        } catch (IOException e) {
            throw new BizException(ResultCode.BAD_REQUEST, "文件存储失败: " + e.getMessage());
        }
    }
}
