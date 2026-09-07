package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.DailyCaseDefect;
import com.zhiyu.entity.DailyCaseRecord;
import com.zhiyu.entity.DailyCaseSchedule;
import com.zhiyu.entity.DailyCaseSegment;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.DailyCaseDefectMapper;
import com.zhiyu.mapper.DailyCaseRecordMapper;
import com.zhiyu.mapper.DailyCaseScheduleMapper;
import com.zhiyu.mapper.DailyCaseSegmentMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.DailyCaseService;
import com.zhiyu.service.DailyMrService;
import com.zhiyu.service.dto.DailyMrHintDTO;
import com.zhiyu.service.dto.DailyMrSubmitDTO;
import com.zhiyu.vo.DailyMrBankItemVO;
import com.zhiyu.vo.DailyMrDetailVO;
import com.zhiyu.vo.DailyMrTodayVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * 每日病历服务实现（每日一例升级版，V43）。
 *
 * 复用：排期与今日缓存逻辑全部复用 {@link DailyCaseService}；AI 调用复用
 * AiPlatformClient → evaluator 分组网关（action=mr_hint / mr_review）。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DailyMrServiceImpl implements DailyMrService {

    /** 业务时区：容器为 UTC，日期必须显式按北京时间计算 */
    private static final ZoneId ZONE_CN = ZoneId.of("Asia/Shanghai");
    private static final DateTimeFormatter TS_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    /** 九段定义：key / 名称 / 段序 / 满分 / 书写规范（AI 提示与前端模板共用） */
    private record SegDef(String key, String name, int order, int full, String spec) {}

    private static final List<SegDef> SEGMENTS = List.of(
            new SegDef("chief_complaint", "主诉", 1, 8,
                    "不超过20字，症状+持续时间，不写诊断词"),
            new SegDef("history_present", "现病史", 2, 25,
                    "起病情况与诱因、症状特点、时序演变、伴随症状、诊治经过、发病以来一般情况（精神/食欲/睡眠/体重/大小便）"),
            new SegDef("history_past", "既往史", 3, 10,
                    "既往疾病、传染病史、手术外伤史、过敏史，以及个人史、家族史中与本次疾病相关的要点"),
            new SegDef("physical_exam", "体格检查", 4, 15,
                    "生命体征（T/P/R/BP）开头，按一般→头颈→胸→腹→脊柱四肢→神经顺序，记录阳性体征与有鉴别意义的阴性体征"),
            new SegDef("auxiliary_exam", "辅助检查", 5, 7,
                    "列出已有检查及关键结果，选择应针对诊断假设"),
            new SegDef("diagnosis", "初步诊断", 6, 8,
                    "诊断完整（病因/部位/分型），主要诊断在前"),
            new SegDef("diagnosis_basis", "诊断依据", 7, 10,
                    "逐条列出，引用病历中具体的症状、体征、检查结果"),
            new SegDef("differential", "鉴别诊断", 8, 12,
                    "至少2个疾病，每个写明支持点与排除点"),
            new SegDef("treatment_plan", "诊疗计划", 9, 5,
                    "进一步检查、治疗方案、随访安排，须针对本患者"));

    /** 缺陷标签中文名（与 V43 mr_defect_tag 字典一致，统计展示用） */
    private static final Map<String, String> TAG_NAMES = Map.ofEntries(
            Map.entry("CC_TOO_LONG", "主诉超过20字"), Map.entry("CC_HAS_DIAGNOSIS", "主诉含诊断性词语"),
            Map.entry("CC_NO_DURATION", "主诉缺时限"), Map.entry("HPI_NO_ONSET", "现病史缺起病情况"),
            Map.entry("HPI_NO_COURSE", "现病史缺病情演变"), Map.entry("HPI_NO_CAUSE", "现病史缺诱因"),
            Map.entry("HPI_NO_RELIEF", "缺缓解/加重因素"), Map.entry("HPI_NO_GENERAL", "缺一般情况"),
            Map.entry("HPI_TIMELINE_CHAOS", "现病史时序混乱"), Map.entry("PMH_MISSING", "既往史缺失"),
            Map.entry("PMH_NO_FILTER", "既往史未筛选相关性"), Map.entry("PE_NO_VITALS", "查体缺生命体征"),
            Map.entry("PE_NO_POSITIVE", "缺阳性体征"), Map.entry("PE_NO_NEGATIVE", "缺鉴别意义阴性体征"),
            Map.entry("PE_DISORDER", "查体顺序混乱"), Map.entry("AE_MISSING", "辅助检查缺失"),
            Map.entry("AE_IRRATIONAL", "检查选择不合理"), Map.entry("DX_INCOMPLETE", "初步诊断不完整"),
            Map.entry("DX_ORDER", "诊断主次顺序不当"), Map.entry("BASIS_INSUFFICIENT", "诊断依据不充分"),
            Map.entry("BASIS_NO_QUOTE", "依据未引用病历内容"), Map.entry("DDX_INSUFFICIENT", "鉴别诊断不足2个"),
            Map.entry("DDX_NO_SUPPORT", "鉴别无支持点"), Map.entry("DDX_NO_EXCLUDE", "鉴别无排除点"),
            Map.entry("PLAN_GENERIC", "诊疗计划泛化"), Map.entry("PLAN_NO_FOLLOWUP", "诊疗计划缺随访"),
            Map.entry("TERM_ERROR", "医学术语使用错误"), Map.entry("LOGIC_CONFLICT", "内容前后矛盾"));

    private final DailyCaseService dailyCaseService;
    private final DailyCaseScheduleMapper scheduleMapper;
    private final DailyCaseRecordMapper recordMapper;
    private final DailyCaseSegmentMapper segmentMapper;
    private final DailyCaseDefectMapper defectMapper;
    private final SpCaseConfigMapper caseMapper;
    private final SysUserMapper userMapper;
    private final ChatSessionMapper chatSessionMapper;
    private final AiPlatformClient aiPlatformClient;
    private final ObjectMapper objectMapper;

    private static LocalDate todayCn() {
        return LocalDate.now(ZONE_CN);
    }

    // ==================== 学生端 ====================

    @Override
    public DailyMrTodayVO todayMr() {
        var today = dailyCaseService.today(); // 复用排期 + 全局缓存 + 日期兜底
        if (today == null || today.getScheduleId() == null) {
            return null;
        }
        Long studentId = UserContext.requireUserId();

        DailyCaseRecord latest = latestRecord(today.getScheduleId(), studentId);
        List<DailyCaseRecord> myAll = recordMapper.selectList(
                new LambdaQueryWrapper<DailyCaseRecord>()
                        .select(DailyCaseRecord::getScheduleId) // 连击只需 schedule_id→日期，收窄查询降低全量扫描
                        .eq(DailyCaseRecord::getStudentId, studentId)
                        .in(DailyCaseRecord::getStatus, 1, 2));

        return DailyMrTodayVO.builder()
                .scheduleId(today.getScheduleId())
                .caseId(today.getCaseId())
                .caseTitle(today.getCaseTitle())
                .department(today.getDepartment())
                .difficulty(today.getDifficulty())
                .publishDate(today.getPublishDate())
                .patientProfile(today.getPatientProfile())
                .keyFindings(today.getKeyFindings())
                .streak(calcStreak(collectDates(myAll)))
                .doneToday(latest != null && latest.getStatus() != null && latest.getStatus() >= 1)
                .myRecord(latest == null ? null : DailyMrTodayVO.MyRecord.builder()
                        .recordId(latest.getId())
                        .version(latest.getVersion())
                        .totalScore(latest.getTeacherScore() != null ? latest.getTeacherScore() : latest.getTotalScore())
                        .status(latest.getStatus())
                        .aiConfidence(latest.getAiConfidence())
                        .build())
                .build();
    }

    @Override
    public PageResult<DailyMrBankItemVO> bank(int pageNum, int pageSize, Integer done) {
        Page<DailyCaseSchedule> page = new Page<>(pageNum, pageSize);
        scheduleMapper.selectPage(page, new LambdaQueryWrapper<DailyCaseSchedule>()
                .eq(DailyCaseSchedule::getStatus, 2)
                .le(DailyCaseSchedule::getPublishDate, todayCn()) // 未到期的排期不入库（防剧透）
                .orderByDesc(DailyCaseSchedule::getPublishDate));

        Long studentId = UserContext.requireUserId();
        List<Long> scheduleIds = page.getRecords().stream().map(DailyCaseSchedule::getId).toList();
        Map<Long, List<DailyCaseRecord>> mine = scheduleIds.isEmpty() ? Map.of()
                : recordMapper.selectList(new LambdaQueryWrapper<DailyCaseRecord>()
                        .eq(DailyCaseRecord::getStudentId, studentId)
                        .in(DailyCaseRecord::getScheduleId, scheduleIds)
                        .in(DailyCaseRecord::getStatus, 1, 2))
                .stream().collect(Collectors.groupingBy(DailyCaseRecord::getScheduleId));

        List<DailyMrBankItemVO> items = new ArrayList<>();
        for (DailyCaseSchedule s : page.getRecords()) {
            SpCaseConfig c = s.getCaseId() == null ? null : caseMapper.selectById(s.getCaseId());
            List<DailyCaseRecord> records = mine.getOrDefault(s.getId(), List.of());
            boolean isDone = !records.isEmpty();
            if (done != null && done == 1 && !isDone) continue;
            if (done != null && done == 0 && isDone) continue;
            DailyCaseRecord latest = records.stream()
                    .max(Comparator.comparing(DailyCaseRecord::getVersion)).orElse(null);
            items.add(DailyMrBankItemVO.builder()
                    .scheduleId(s.getId())
                    .caseTitle(c == null ? null : c.getTitle())
                    .department(c == null ? null : c.getDepartment())
                    .difficulty(c == null ? null : c.getDifficulty())
                    .publishDate(s.getPublishDate())
                    .done(isDone)
                    .myScore(latest == null ? null
                            : (latest.getTeacherScore() != null ? latest.getTeacherScore() : latest.getTotalScore()))
                    .myVersions(records.size())
                    .build());
        }
        return PageResult.of(page, items);
    }

    @Override
    public DailyMrDetailVO detail(Long scheduleId) {
        DailyCaseSchedule s = requireSchedule(scheduleId);
        SpCaseConfig c = s.getCaseId() == null ? null : caseMapper.selectById(s.getCaseId());
        Long studentId = UserContext.requireUserId();

        List<DailyCaseRecord> records = recordMapper.selectList(
                new LambdaQueryWrapper<DailyCaseRecord>()
                        .eq(DailyCaseRecord::getScheduleId, scheduleId)
                        .eq(DailyCaseRecord::getStudentId, studentId)
                        .orderByDesc(DailyCaseRecord::getVersion));
        boolean submitted = records.stream().anyMatch(r -> r.getStatus() != null && r.getStatus() >= 1);

        List<DailyMrDetailVO.SegmentSpec> segs = SEGMENTS.stream()
                .map(d -> DailyMrDetailVO.SegmentSpec.builder()
                        .key(d.key()).name(d.name()).spec(d.spec())
                        .order(d.order()).fullScore(d.full()).build())
                .toList();

        List<DailyMrDetailVO.MyRecord> myRecords = records.stream()
                .map(r -> DailyMrDetailVO.MyRecord.builder()
                        .recordId(r.getId()).version(r.getVersion()).status(r.getStatus())
                        .totalScore(r.getTeacherScore() != null ? r.getTeacherScore() : r.getTotalScore())
                        .aiConfidence(r.getAiConfidence())
                        .contentJson(r.getContentJson())
                        .reviewJson(submitted ? r.getReviewJson() : null)
                        .teacherComment(r.getTeacherComment())
                        .submittedAt(r.getSubmittedAt() == null ? null : r.getSubmittedAt().format(TS_FMT))
                        .build())
                .toList();

        return DailyMrDetailVO.builder()
                .scheduleId(scheduleId)
                .caseTitle(c == null ? null : c.getTitle())
                .department(c == null ? null : c.getDepartment())
                .difficulty(c == null ? null : c.getDifficulty())
                .publishDate(s.getPublishDate())
                .patientProfile(c == null ? null : c.getPatientProfile())
                .keyFindings(c == null ? null : extractKeyFindings(c))
                .standardAnswer(submitted ? s.getStandardAnswer() : null)
                .referenceRecord(submitted ? s.getReferenceRecord() : null)
                .exams(c == null ? List.of() : extractExamMedia(c))
                .segments(segs)
                .myRecords(myRecords)
                .build();
    }

    @Override
    public Map<String, Object> hint(DailyMrHintDTO dto) {
        DailyCaseSchedule s = requireSchedule(dto.getScheduleId());
        SpCaseConfig c = s.getCaseId() == null ? null : caseMapper.selectById(s.getCaseId());
        Long studentId = UserContext.requireUserId();

        SegDef def = SEGMENTS.stream().filter(d -> d.key().equals(dto.getSegmentKey())).findFirst()
                .orElseThrow(() -> new BizException(ResultCode.BAD_REQUEST, "未知段落: " + dto.getSegmentKey()));

        // 学生该段当前草稿（取最新一条记录，含草稿态）
        DailyCaseRecord latest = latestRecord(dto.getScheduleId(), studentId);
        String draft = "";
        if (latest != null && latest.getContentJson() != null) {
            try {
                Map<String, String> content = objectMapper.readValue(
                        latest.getContentJson(), new TypeReference<Map<String, String>>() {});
                draft = content.getOrDefault(dto.getSegmentKey(), "");
            } catch (Exception e) {
                log.debug("解析草稿失败: {}", e.getMessage());
            }
        }

        int level = dto.getHintLevel() == null ? 1 : Math.max(1, Math.min(3, dto.getHintLevel()));
        try {
            Map<String, Object> data = aiPlatformClient.mrSegmentHint(
                    dto.getScheduleId(), studentId, def.key(), def.name(), def.spec(), level,
                    draft,
                    c == null ? null : c.getPatientProfile(),
                    c == null ? null : extractKeyFindings(c),
                    collectConsultMaterials(studentId, s.getCaseId()));
            if (data != null && data.get("text") != null) {
                data.put("degraded", false);
                return data;
            }
        } catch (Exception e) {
            log.warn("段落教练AI调用失败, 降级为规范提示: {}", e.getMessage());
        }
        // 优雅降级：AI 不可用时给规范自查提示
        Map<String, Object> fallback = new HashMap<>();
        fallback.put("type", level >= 3 ? "example" : (level == 1 ? "question" : "hint"));
        fallback.put("text", "AI 教练暂时离线。请先自查「" + def.name() + "」规范：" + def.spec());
        fallback.put("quoteMaterials", List.of());
        fallback.put("degraded", true);
        return fallback;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> submit(DailyMrSubmitDTO dto) {
        Long studentId = UserContext.requireUserId();
        DailyCaseSchedule s = requireSchedule(dto.getScheduleId());
        // 仅「已发布且到发布时间」的排期允许提交：未发布/未到期的排期不承接作答，
        // 防止按 scheduleId 猜测未来期次提前提交（V43 每日病历公开作答）。
        if (s.getStatus() == null || s.getStatus() != 2
                || s.getPublishDate() == null || s.getPublishDate().isAfter(todayCn())) {
            throw new BizException(ResultCode.BAD_REQUEST, "该期每日病历尚未发布或未到发布时间，不能提交");
        }
        SpCaseConfig c = s.getCaseId() == null ? null : caseMapper.selectById(s.getCaseId());

        // 过滤空白段，至少 1 段非空
        Map<String, String> content = new LinkedHashMap<>();
        dto.getSegments().forEach((k, v) -> {
            if (v != null && !v.isBlank()) content.put(k, v.trim());
        });
        if (content.isEmpty()) {
            throw new BizException(ResultCode.BAD_REQUEST, "至少书写一个段落再提交");
        }
        // 低质量(灌水/占位)作答守卫：LLM 对 "qqq" 这类占位内容常给偏高虚分，
        // 这里先用确定性规则判定，命中则后续对其分数从严封顶，不轻信 LLM 虚分。
        boolean lowEffort = isLowEffortContent(content);

        DailyCaseRecord latest = latestRecord(dto.getScheduleId(), studentId);
        int version = (latest == null || latest.getVersion() == null) ? 1 : latest.getVersion() + 1;

        DailyCaseRecord record = new DailyCaseRecord();
        record.setScheduleId(dto.getScheduleId());
        record.setStudentId(studentId);
        record.setVersion(version);
        record.setStatus(1);
        try {
            record.setContentJson(objectMapper.writeValueAsString(content));
        } catch (Exception e) {
            throw new BizException(ResultCode.BAD_REQUEST, "病历内容序列化失败");
        }

        Map<String, Object> result = new HashMap<>();
        result.put("version", version);
        result.put("degraded", true);
        try {
            Map<String, Object> data = aiPlatformClient.mrReview(
                    null, dto.getScheduleId(), studentId, content,
                    buildCaseContext(s, c, studentId), s.getStandardAnswer());
            if (data != null && data.get("totalScore") != null) {
                record.setStatus(2);
                BigDecimal score = toBigDecimal(data.get("totalScore"));
                BigDecimal conf = toBigDecimal(data.get("confidence"));
                if (lowEffort) {
                    // 灌水作答从严封顶：避免任意短占位内容也被判出高分
                    score = score.min(BigDecimal.valueOf(25));
                    conf = (conf == null) ? BigDecimal.valueOf(0.3) : conf.min(BigDecimal.valueOf(0.3));
                    String baseComment = data.get("reviewComment") == null ? ""
                            : String.valueOf(data.get("reviewComment"));
                    data.put("reviewComment",
                            "检测到作答含较多占位/灌水内容（如重复字符、无实质医学描述）。病历需真实反映"
                                    + "问诊、查体、辅助检查与诊断思路，本次判分从严，请认真书写。 " + baseComment);
                    Object tags = data.get("defectTags");
                    List<String> merged = (tags instanceof List<?> l)
                            ? l.stream().map(String::valueOf).collect(Collectors.toCollection(ArrayList::new))
                            : new ArrayList<>();
                    merged.add("LOW_EFFORT_FILLER");
                    data.put("defectTags", merged);
                    data.put("confidence", conf);
                }
                record.setTotalScore(score);
                record.setAiConfidence(conf);
                record.setReviewJson(objectMapper.writeValueAsString(data));
                result.put("degraded", false);
                result.put("totalScore", score);
                result.put("confidence", data.get("confidence"));
                result.put("reviewComment", data.get("reviewComment"));
                result.put("segments", data.get("segments"));
                result.put("defectTags", data.get("defectTags"));
            }
        } catch (Exception e) {
            log.warn("每日病历AI批阅失败, 降级为待人工批阅: scheduleId={} error={}",
                    dto.getScheduleId(), e.getMessage());
        }

        record.setSubmittedAt(LocalDateTime.now(ZONE_CN));
        recordMapper.insert(record);

        // 段落与缺陷落库（AI 批阅成功时）
        saveSegmentsAndDefects(record, content, result);

        result.put("recordId", record.getId());
        result.put("status", record.getStatus());
        return result;
    }

    /**
     * 判断是否为低质量(灌水/占位)作答：
     * 当一个段落去空白后不包含汉字、且长度过短（如 "qqq"、".!?"、单个符号堆积），视为占位段；
     * 占位段占提交段过半，或全部提交内容有效字符过少，判定为灌水作答，判分从严。
     */
    private boolean isLowEffortContent(Map<String, String> content) {
        int total = 0;
        int junk = 0;
        for (String v : content.values()) {
            if (v == null) continue;
            String t = v.replaceAll("\\s+", "");
            total += t.length();
            boolean hasCjk = t.codePoints().anyMatch(
                    cp -> Character.UnicodeScript.of(cp) == Character.UnicodeScript.HAN);
            if (!hasCjk && t.length() <= 4) junk++;
        }
        double junkRatio = (double) junk / content.size();
        return junkRatio >= 0.5 || total < 15;
    }

    private void saveSegmentsAndDefects(DailyCaseRecord record, Map<String, String> content,
                                        Map<String, Object> result) {
        LocalDate publishDate = null;
        DailyCaseSchedule s = scheduleMapper.selectById(record.getScheduleId());
        if (s != null) publishDate = s.getPublishDate();

        List<Map<String, Object>> reviewedSegs = result.get("segments") instanceof List<?> list
                ? list.stream().filter(o -> o instanceof Map).map(o -> (Map<String, Object>) o).toList()
                : List.of();
        Map<String, Map<String, Object>> segByKey = reviewedSegs.stream()
                .filter(m -> m.get("key") != null)
                .collect(Collectors.toMap(m -> String.valueOf(m.get("key")), Function.identity(), (a, b) -> a));

        for (SegDef def : SEGMENTS) {
            String text = content.get(def.key());
            Map<String, Object> seg = segByKey.get(def.key());
            if ((text == null || text.isBlank()) && seg == null) continue;
            DailyCaseSegment entity = new DailyCaseSegment();
            entity.setRecordId(record.getId());
            entity.setSegmentKey(def.key());
            entity.setSegmentOrder(def.order());
            entity.setContent(text);
            if (seg != null) {
                entity.setScore(toBigDecimal(seg.get("score")));
                entity.setFullScore(BigDecimal.valueOf(def.full()));
                entity.setFeedbackJson(safeJson(seg));
                saveDefects(record, def.key(), seg, publishDate);
            } else {
                entity.setFullScore(BigDecimal.valueOf(def.full()));
            }
            try {
                segmentMapper.insert(entity);
            } catch (Exception e) {
                log.warn("段落落库失败(不影响提交): recordId={} seg={} err={}",
                        record.getId(), def.key(), e.getMessage());
            }
        }
    }

    @SuppressWarnings("unchecked")
    private void saveDefects(DailyCaseRecord record, String segmentKey, Map<String, Object> seg,
                             LocalDate publishDate) {
        Object defects = seg.get("defects");
        if (!(defects instanceof List<?> list)) return;
        for (Object o : list) {
            if (!(o instanceof Map<?, ?> m) || m.get("tag") == null) continue;
            DailyCaseDefect d = new DailyCaseDefect();
            d.setRecordId(record.getId());
            d.setScheduleId(record.getScheduleId());
            d.setStudentId(record.getStudentId());
            d.setSegmentKey(segmentKey);
            d.setTagCode(String.valueOf(m.get("tag")));
            d.setLevel(m.get("level") instanceof Number n ? n.intValue() : 1);
            d.setPublishDate(publishDate);
            try {
                defectMapper.insert(d);
            } catch (Exception e) {
                log.debug("缺陷落库失败: {}", e.getMessage());
            }
        }
    }

    @Override
    public Map<String, Object> calendar(Integer year) {
        Long studentId = UserContext.requireUserId();
        int y = year == null ? todayCn().getYear() : year;
        List<DailyCaseRecord> records = recordMapper.selectList(
                new LambdaQueryWrapper<DailyCaseRecord>()
                        .select(DailyCaseRecord::getScheduleId) // collectDates 只依赖 schedule_id，收窄查询
                        .eq(DailyCaseRecord::getStudentId, studentId)
                        .in(DailyCaseRecord::getStatus, 1, 2));
        Set<LocalDate> dates = collectDates(records).stream()
                .filter(d -> d.getYear() == y).collect(Collectors.toSet());
        Map<String, Object> res = new HashMap<>();
        res.put("year", y);
        res.put("days", dates.stream().map(LocalDate::toString).sorted().toList());
        res.put("streak", calcStreak(collectDates(records)));
        res.put("totalDone", records.size());
        return res;
    }

    // ==================== 教师端 ====================

    @Override
    public List<Map<String, Object>> schedules(int limit) {
        Page<DailyCaseSchedule> page = new Page<>(1, Math.min(Math.max(limit, 1), 100));
        scheduleMapper.selectPage(page, new LambdaQueryWrapper<DailyCaseSchedule>()
                .eq(DailyCaseSchedule::getStatus, 2)
                .orderByDesc(DailyCaseSchedule::getPublishDate));
        return page.getRecords().stream().map(s -> {
            SpCaseConfig c = s.getCaseId() == null ? null : caseMapper.selectById(s.getCaseId());
            Map<String, Object> row = new HashMap<>();
            row.put("scheduleId", s.getId());
            row.put("publishDate", s.getPublishDate() == null ? null : s.getPublishDate().toString());
            row.put("caseTitle", c == null ? null : c.getTitle());
            row.put("department", c == null ? null : c.getDepartment());
            row.put("difficulty", c == null ? null : c.getDifficulty());
            return row;
        }).toList();
    }

    @Override
    public PageResult<Map<String, Object>> teacherRecords(Long scheduleId, int pageNum, int pageSize) {
        requireSchedule(scheduleId);
        Page<DailyCaseRecord> page = new Page<>(pageNum, pageSize);
        recordMapper.selectPage(page, new LambdaQueryWrapper<DailyCaseRecord>()
                .eq(DailyCaseRecord::getScheduleId, scheduleId)
                .ge(DailyCaseRecord::getStatus, 1)
                .orderByDesc(DailyCaseRecord::getId));

        Set<Long> studentIds = page.getRecords().stream()
                .map(DailyCaseRecord::getStudentId).collect(Collectors.toSet());
        Map<Long, String> names = studentIds.isEmpty() ? Map.of()
                : userMapper.selectBatchIds(studentIds).stream()
                        .collect(Collectors.toMap(SysUser::getId, u ->
                                u.getRealName() == null ? u.getUsername() : u.getRealName()));

        List<Map<String, Object>> rows = page.getRecords().stream().map(r -> {
            boolean needReview = r.getAiConfidence() == null
                    || r.getAiConfidence().compareTo(BigDecimal.valueOf(0.85)) < 0;
            Map<String, Object> row = new HashMap<>();
            row.put("recordId", r.getId());
            row.put("studentId", r.getStudentId());
            row.put("studentName", names.getOrDefault(r.getStudentId(), "学生#" + r.getStudentId()));
            row.put("version", r.getVersion());
            row.put("status", r.getStatus());
            row.put("totalScore", r.getTeacherScore() != null ? r.getTeacherScore() : r.getTotalScore());
            row.put("aiScore", r.getTotalScore());
            row.put("aiConfidence", r.getAiConfidence());
            row.put("needReview", needReview);
            row.put("reviewed", r.getTeacherScore() != null);
            row.put("teacherComment", r.getTeacherComment());
            row.put("contentJson", r.getContentJson());
            row.put("reviewJson", r.getReviewJson());
            row.put("submittedAt", r.getSubmittedAt() == null ? null : r.getSubmittedAt().format(TS_FMT));
            return row;
        }).toList();
        return PageResult.of(page, rows);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> teacherReview(Long recordId, Double score, String comment) {
        Long teacherId = UserContext.requireUserId();
        DailyCaseRecord r = recordMapper.selectById(recordId);
        if (r == null) throw new BizException(ResultCode.NOT_FOUND, "病历记录不存在");
        if (score != null && (score < 0 || score > 100)) {
            throw new BizException(ResultCode.BAD_REQUEST, "分数须在 0-100 之间");
        }
        if (score != null) r.setTeacherScore(BigDecimal.valueOf(score).setScale(1, RoundingMode.HALF_UP));
        r.setTeacherComment(comment);
        r.setReviewedBy(teacherId);
        if (r.getStatus() != null && r.getStatus() < 2) r.setStatus(2);
        recordMapper.updateById(r);

        Map<String, Object> res = new HashMap<>();
        res.put("recordId", r.getId());
        res.put("teacherScore", r.getTeacherScore());
        res.put("teacherComment", r.getTeacherComment());
        return res;
    }

    @Override
    public List<Map<String, Object>> defectStats(Long scheduleId) {
        QueryWrapper<DailyCaseDefect> qw = new QueryWrapper<>();
        qw.select("tag_code", "COUNT(*) AS cnt", "COUNT(DISTINCT student_id) AS students")
                .eq(scheduleId != null, "schedule_id", scheduleId)
                .groupBy("tag_code")
                .orderByDesc("cnt");
        return defectMapper.selectMaps(qw).stream().map(m -> {
            String code = String.valueOf(m.get("tag_code"));
            Map<String, Object> row = new HashMap<>();
            row.put("tagCode", code);
            row.put("tagName", TAG_NAMES.getOrDefault(code, code));
            row.put("count", m.get("cnt"));
            row.put("students", m.get("students"));
            return row;
        }).toList();
    }

    // ==================== 私有工具 ====================

    private DailyCaseSchedule requireSchedule(Long scheduleId) {
        DailyCaseSchedule s = scheduleMapper.selectById(scheduleId);
        if (s == null) throw new BizException(ResultCode.NOT_FOUND, "该期每日病历不存在");
        return s;
    }

    private DailyCaseRecord latestRecord(Long scheduleId, Long studentId) {
        return recordMapper.selectOne(new LambdaQueryWrapper<DailyCaseRecord>()
                .eq(DailyCaseRecord::getScheduleId, scheduleId)
                .eq(DailyCaseRecord::getStudentId, studentId)
                .orderByDesc(DailyCaseRecord::getVersion)
                .last("LIMIT 1"));
    }

    private Set<LocalDate> collectDates(List<DailyCaseRecord> records) {
        if (records.isEmpty()) return Set.of();
        Map<Long, LocalDate> scheduleDates = new HashMap<>();
        records.stream().map(DailyCaseRecord::getScheduleId).distinct().forEach(sid -> {
            DailyCaseSchedule s = scheduleMapper.selectById(sid);
            if (s != null && s.getPublishDate() != null) scheduleDates.put(sid, s.getPublishDate());
        });
        return records.stream()
                .map(r -> scheduleDates.get(r.getScheduleId()))
                .filter(d -> d != null)
                .collect(Collectors.toSet());
    }

    /** LeetCode 式连续打卡：今天没做不打断（从昨天起算），断一天归零 */
    private int calcStreak(Set<LocalDate> days) {
        if (days.isEmpty()) return 0;
        LocalDate d = todayCn();
        if (!days.contains(d)) {
            d = d.minusDays(1);
            if (!days.contains(d)) return 0;
        }
        int streak = 0;
        while (days.contains(d)) {
            streak++;
            d = d.minusDays(1);
        }
        return streak;
    }

    private String buildCaseContext(DailyCaseSchedule s, SpCaseConfig c, Long studentId) {
        StringBuilder sb = new StringBuilder();
        if (c != null) {
            if (c.getTitle() != null) sb.append("病例：").append(c.getTitle()).append('\n');
            if (c.getDepartment() != null) sb.append("科室：").append(c.getDepartment()).append('\n');
            if (c.getPatientProfile() != null) sb.append("患者画像：\n").append(c.getPatientProfile()).append('\n');
            String kf = extractKeyFindings(c);
            if (kf != null && !kf.isBlank()) sb.append("关键检查结果：\n").append(kf).append('\n');
        }
        if (s.getQuestion() != null && !s.getQuestion().isBlank()) {
            sb.append("附加题目要求：").append(s.getQuestion()).append('\n');
        }
        // 该学生对此病例的问诊复盘：供批阅对照其书写是否遗漏了问诊中已获取的信息
        List<String> materials = collectConsultMaterials(studentId, s.getCaseId());
        if (!materials.isEmpty()) {
            sb.append("该学生此前问诊复盘（对照参考，书写遗漏可据此扣分提示）：\n")
              .append(String.join("\n", materials)).append('\n');
        }
        return sb.toString();
    }

    /**
     * 素材回捞：取该学生对该病例最近一次已完成问诊的复盘报告。
     * 把「问诊」与「书写」串成一条训练链——问诊获取的信息可用于书写与批阅对照。
     */
    private List<String> collectConsultMaterials(Long studentId, Long caseId) {
        try {
            if (caseId == null) return List.of();
            ChatSession session = chatSessionMapper.selectOne(
                    new LambdaQueryWrapper<ChatSession>()
                            .eq(ChatSession::getStudentId, studentId)
                            .eq(ChatSession::getCaseId, caseId)
                            .eq(ChatSession::getStatus, 1)
                            .orderByDesc(ChatSession::getId)
                            .last("LIMIT 1"));
            if (session == null || session.getFinalReport() == null
                    || session.getFinalReport().isBlank()) {
                return List.of();
            }
            String report = session.getFinalReport().trim();
            if (report.length() > 1200) {
                report = report.substring(0, 1200) + "…";
            }
            return List.of("问诊复盘报告：" + report);
        } catch (Exception e) {
            log.debug("查询问诊复盘失败(不影响主流程): {}", e.getMessage());
            return List.of();
        }
    }

    /** 从病例 presetExams 提取检查项媒体附件（仅名称+图片URL，不带结论防剧透） */
    private List<Map<String, Object>> extractExamMedia(SpCaseConfig c) {
        String json = c == null ? null : c.getPresetExams();
        if (json == null || json.isBlank()) return List.of();
        try {
            com.fasterxml.jackson.databind.JsonNode arr = objectMapper.readTree(json);
            if (!arr.isArray()) return List.of();
            List<Map<String, Object>> out = new ArrayList<>();
            for (com.fasterxml.jackson.databind.JsonNode it : arr) {
                String name = it.path("name").asText("");
                com.fasterxml.jackson.databind.JsonNode result = it.path("result");
                List<String> urls = new ArrayList<>();
                if (result.isObject()) {
                    for (com.fasterxml.jackson.databind.JsonNode u : result.path("imageUrls")) {
                        if (u.isTextual() && !u.asText().isBlank()) urls.add(u.asText());
                    }
                    for (com.fasterxml.jackson.databind.JsonNode u : result.path("imageUrl")) {
                        if (u.isTextual() && !u.asText().isBlank()) urls.add(u.asText());
                    }
                }
                if (name.isBlank() || urls.isEmpty()) continue;
                Map<String, Object> row = new HashMap<>();
                row.put("name", name);
                row.put("imageUrls", urls);
                out.add(row);
            }
            return out;
        } catch (Exception e) {
            return List.of();
        }
    }

    /** 从病例 presetExams 提取关键检查展示文本（与 DailyCaseServiceImpl 同策略） */
    private String extractKeyFindings(SpCaseConfig c) {
        String json = c == null ? null : c.getPresetExams();
        if (json == null || json.isBlank()) return null;
        try {
            com.fasterxml.jackson.databind.JsonNode arr = objectMapper.readTree(json);
            if (!arr.isArray()) return json;
            StringBuilder sb = new StringBuilder();
            for (com.fasterxml.jackson.databind.JsonNode it : arr) {
                String name = it.path("name").asText("");
                // result 兼容两种形态：纯文本（旧数据）或对象 {kind, conclusion, imageUrls}（多模态）
                com.fasterxml.jackson.databind.JsonNode resultNode = it.path("result");
                String result = resultNode.isObject()
                        ? resultNode.path("conclusion").asText("")
                        : resultNode.asText("");
                if (name.isBlank() && result.isBlank()) continue;
                if (sb.length() > 0) sb.append('\n');
                sb.append(name).append("：").append(result);
            }
            return sb.isEmpty() ? null : sb.toString();
        } catch (Exception e) {
            return json;
        }
    }

    private BigDecimal toBigDecimal(Object v) {
        try {
            return new BigDecimal(String.valueOf(v));
        } catch (Exception e) {
            return null;
        }
    }

    private String safeJson(Object o) {
        try {
            return objectMapper.writeValueAsString(o);
        } catch (Exception e) {
            return null;
        }
    }
}
