package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.entity.DailyCaseSchedule;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.DailyCaseScheduleMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.DailyCaseService;
import com.zhiyu.service.dto.DailyCaseScheduleDTO;
import com.zhiyu.vo.DailyCaseVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;

/**
 * 每日一例服务实现（PRD 4.10 / 4.16 / 8.10）
 *
 * <p>负责排期管理 + 「今日排期」解析（Redis 缓存 + 日期兜底 + 自动轮转排期）。
 * 旧版开放作答提交链路（submitAnswer / AI 判题 / 错题入库）已随移动端切换到
 * 九段病历版（DailyMrService）下线。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DailyCaseServiceImpl implements DailyCaseService {

    // v2：结构升级（新增 patientProfile/keyFindings），与旧缓存不兼容故提升版本号
    private static final String TODAY_KEY = "daily_case_today_v2";
    private static final Duration TODAY_TTL = Duration.ofDays(2);

    /** 业务时区：容器为 UTC，日期必须显式按北京时间计算，否则 0~8 点会取到前一天 */
    private static final ZoneId ZONE_CN = ZoneId.of("Asia/Shanghai");

    private static LocalDate todayCn() {
        return LocalDate.now(ZONE_CN);
    }

    private final DailyCaseScheduleMapper scheduleMapper;
    private final SpCaseConfigMapper caseMapper;
    private final ChatSessionMapper chatSessionMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;
    private final StringRedisTemplate redisTemplate;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long schedule(DailyCaseScheduleDTO dto) {
        Long adminId = UserContext.requireUserId();

        // 校验病例存在
        SpCaseConfig c = caseMapper.selectById(dto.getCaseId());
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }

        // 同一日期只能有一个排期（uk_date 唯一索引）
        Long exists = scheduleMapper.selectCount(
                new LambdaQueryWrapper<DailyCaseSchedule>()
                        .eq(DailyCaseSchedule::getPublishDate, dto.getPublishDate()));
        if (exists != null && exists > 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "该日期已有排期，请先删除或更换日期");
        }

        DailyCaseSchedule schedule = new DailyCaseSchedule();
        schedule.setCaseId(dto.getCaseId());
        schedule.setPublishDate(dto.getPublishDate());
        schedule.setTargetGrade(dto.getTargetGrade());
        schedule.setStatus(2); // 直接发布
        schedule.setCreatedBy(adminId);
        scheduleMapper.insert(schedule);

        auditLogService.record("daily_case_schedule", "daily_case_schedule", schedule.getId(),
                null, "{\"caseId\":" + dto.getCaseId() + ",\"date\":\"" + dto.getPublishDate() + "\"}");
        log.info("管理员{}排期每日一例: scheduleId={} date={}", adminId, schedule.getId(), dto.getPublishDate());
        return schedule.getId();
    }

    @Override
    public PageResult<DailyCaseVO> scheduleList(Integer pageNum, Integer pageSize) {
        Page<DailyCaseSchedule> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<DailyCaseSchedule> wrapper = new LambdaQueryWrapper<DailyCaseSchedule>()
                .orderByDesc(DailyCaseSchedule::getPublishDate);
        scheduleMapper.selectPage(page, wrapper);

        var list = page.getRecords().stream().map(s -> {
            SpCaseConfig c = s.getCaseId() == null ? null : caseMapper.selectById(s.getCaseId());
            return DailyCaseVO.builder()
                    .scheduleId(s.getId())
                    .caseId(s.getCaseId())
                    .caseTitle(c == null ? null : c.getTitle())
                    .department(c == null ? null : c.getDepartment())
                    .difficulty(c == null ? null : c.getDifficulty())
                    .publishDate(s.getPublishDate())
                    .targetGrade(s.getTargetGrade())
                    .patientProfile(c == null ? null : c.getPatientProfile())
                    .keyFindings(c == null ? null : extractKeyFindings(c.getPresetExams()))
                    .question(s.getQuestion())
                    .optionsJson(s.getOptionsJson())
                    .textbookRef(s.getTextbookRef())
                    .status(s.getStatus())
                    .build();
        }).toList();
        return PageResult.of(page, list);
    }

    @Override
    public DailyCaseVO today() {
        String cached = redisTemplate.opsForValue().get(TODAY_KEY);
        DailyCaseVO vo;
        if (cached != null && !cached.isBlank()) {
            vo = parseVo(cached);
            // 日期兜底：缓存里的 publishDate 不是今天（如容器重启错过 0 点 cron、TTL 未到期）一律视为过期，
            // 立即按当天日期重新排期，绝不把昨天的题留给学生
            if (vo != null && !todayCn().equals(vo.getPublishDate())) {
                log.info("每日一例缓存日期过期: cachedDate={} today={}, 重新排期", vo.getPublishDate(), todayCn());
                vo = null;
            }
            if (vo == null) {
                vo = resolveAndCacheToday();
            }
        } else {
            vo = resolveAndCacheToday();
        }
        // 病例内容全局缓存，但「已做/进行中/未做」是按学生实时计算的个人状态，逐请求查询拼接
        if (vo != null && vo.getCaseId() != null) {
            vo.setLastSessionStatus(resolveSessionStatus(vo.getCaseId()));
        }
        return vo;
    }

    /** 当前学生对指定病例最近一次问诊状态：null未做过 / 0进行中 / 1已完成 / 2评估异常 */
    private Integer resolveSessionStatus(Long caseId) {
        try {
            Long studentId = UserContext.requireUserId();
            if (studentId == null) {
                return null;
            }
            ChatSession last = chatSessionMapper.selectOne(
                    new LambdaQueryWrapper<ChatSession>()
                            .eq(ChatSession::getStudentId, studentId)
                            .eq(ChatSession::getCaseId, caseId)
                            .in(ChatSession::getStatus, 0, 1, 2)
                            .orderByDesc(ChatSession::getId)
                            .last("LIMIT 1"));
            return last == null ? null : last.getStatus();
        } catch (Exception e) {
            log.debug("每日一例查询个人问诊状态失败: {}", e.getMessage());
            return null;
        }
    }

    /** 每天 0 点自动排期（按北京时间；可用 zhiyu.daily-case.cron 覆盖） */
    @Scheduled(cron = "${zhiyu.daily-case.cron:0 0 0 * * *}", zone = "Asia/Shanghai")
    public void autoScheduleToday() {
        LocalDate today = todayCn();
        log.info("每日一例自动排期开始: date={}", today);
        DailyCaseSchedule s = selectTodaySchedule();
        if (s != null) {
            log.info("今日已有手动排期, 直接写缓存");
            writeToRedis(buildVo(s, caseMapper.selectById(s.getCaseId())));
            return;
        }
        DailyCaseSchedule picked = tryAutoPickToday();
        if (picked == null) {
            log.warn("自动排期: 今日无可用（未使用）病例, 跳过");
            return;
        }
        writeToRedis(buildVo(picked, caseMapper.selectById(picked.getCaseId())));
    }

    /** 读当天：先 Redis，未命中回填 */
    private DailyCaseVO resolveAndCacheToday() {
        DailyCaseSchedule s = selectTodaySchedule();
        if (s == null) {
            s = tryAutoPickToday();
            if (s == null) {
                return null;
            }
        }
        SpCaseConfig c = caseMapper.selectById(s.getCaseId());
        DailyCaseVO vo = buildVo(s, c);
        writeToRedis(vo);
        return vo;
    }

    private DailyCaseSchedule selectTodaySchedule() {
        return scheduleMapper.selectOne(new LambdaQueryWrapper<DailyCaseSchedule>()
                .eq(DailyCaseSchedule::getPublishDate, LocalDate.now())
                .eq(DailyCaseSchedule::getStatus, 2).last("LIMIT 1"));
    }

    @Transactional(rollbackFor = Exception.class)
    protected DailyCaseSchedule tryAutoPickToday() {
        // 最久未推荐优先：先用从未上过的，用完从库里轮转复用，池子不会耗尽
        SpCaseConfig c = caseMapper.selectRandomDailyCase();
        if (c == null) {
            return null;
        }
        LocalDate today = todayCn();
        DailyCaseSchedule s = new DailyCaseSchedule();
        s.setCaseId(c.getId());
        s.setPublishDate(today);
        s.setStatus(2);
        try {
            scheduleMapper.insert(s);
        } catch (DuplicateKeyException e) {
            DailyCaseSchedule exists = selectTodaySchedule();
            if (exists != null) {
                return exists;
            }
            throw e;
        }
        caseMapper.markAsDaily(c.getId(), today);
        log.info("自动排期每日一例: caseId={} date={}", c.getId(), today);
        return s;
    }

    private DailyCaseVO buildVo(DailyCaseSchedule s, SpCaseConfig c) {
        return DailyCaseVO.builder()
                .scheduleId(s.getId())
                .caseId(s.getCaseId())
                .caseTitle(c == null ? null : c.getTitle())
                .department(c == null ? null : c.getDepartment())
                .difficulty(c == null ? null : c.getDifficulty())
                .publishDate(s.getPublishDate())
                .targetGrade(s.getTargetGrade())
                .patientProfile(c == null ? null : c.getPatientProfile())
                .keyFindings(c == null ? null : extractKeyFindings(c.getPresetExams()))
                .question(s.getQuestion())
                .optionsJson(s.getOptionsJson())
                .textbookRef(s.getTextbookRef())
                .status(s.getStatus())
                .build();
    }

    /** 将 presetExams JSON 数组格式化为可展示文本：每项"项目：结果"一行，方便画像+检查全展示 */
    private String extractKeyFindings(String presetExamsJson) {
        if (presetExamsJson == null || presetExamsJson.isBlank()) {
            return null;
        }
        try {
            JsonNode arr = objectMapper.readTree(presetExamsJson);
            if (!arr.isArray()) {
                return presetExamsJson;
            }
            StringBuilder sb = new StringBuilder();
            for (JsonNode it : arr) {
                String name = it.path("name").asText("");
                // result 兼容两种形态：纯文本（旧数据）或对象 {kind, conclusion, imageUrls}（多模态）
                JsonNode resultNode = it.path("result");
                String result = resultNode.isObject()
                        ? resultNode.path("conclusion").asText("")
                        : resultNode.asText("");
                if (name.isBlank() && result.isBlank()) {
                    continue;
                }
                if (sb.length() > 0) {
                    sb.append("\n");
                }
                sb.append(name).append("：").append(result);
            }
            return sb.length() == 0 ? null : sb.toString();
        } catch (Exception e) {
            return presetExamsJson;
        }
    }

    private void writeToRedis(DailyCaseVO vo) {
        try {
            redisTemplate.opsForValue().set(TODAY_KEY, toJson(vo), TODAY_TTL);
        } catch (Exception e) {
            log.warn("写入每日一例 Redis 缓存失败: {}", e.getMessage());
        }
    }

    private String toJson(DailyCaseVO vo) {
        try {
            return objectMapper.writeValueAsString(vo);
        } catch (Exception e) {
            return null;
        }
    }

    private DailyCaseVO parseVo(String json) {
        try {
            JsonNode n = objectMapper.readTree(json);
            String pDate = n.path("publishDate").asText("");
            return DailyCaseVO.builder()
                    .scheduleId(n.path("scheduleId").isNull() ? null : n.path("scheduleId").asLong())
                    .caseId(n.path("caseId").isNull() ? null : n.path("caseId").asLong())
                    .caseTitle(textOrNull(n.path("caseTitle")))
                    .department(textOrNull(n.path("department")))
                    .difficulty(n.path("difficulty").isNull() ? null : n.path("difficulty").asInt())
                    .publishDate(pDate.isEmpty() ? null : LocalDate.parse(pDate))
                    .targetGrade(textOrNull(n.path("targetGrade")))
                    .patientProfile(textOrNull(n.path("patientProfile")))
                    .keyFindings(textOrNull(n.path("keyFindings")))
                    .question(textOrNull(n.path("question")))
                    .optionsJson(textOrNull(n.path("optionsJson")))
                    .textbookRef(textOrNull(n.path("textbookRef")))
                    .status(n.path("status").isNull() ? null : n.path("status").asInt())
                    .build();
        } catch (Exception e) {
            return null;
        }
    }

    private static String textOrNull(JsonNode node) {
        if (node == null || node.isNull()) {
            return null;
        }
        String s = node.asText("");
        return s.isEmpty() ? null : s;
    }
}
