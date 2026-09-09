package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.SysUser;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.service.CaseMarketService;
import com.zhiyu.vo.CaseMarketListVO;
import com.zhiyu.vo.CaseMarketDetailVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 病例广场服务实现（PRD 4.2）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CaseMarketServiceImpl implements CaseMarketService {

    /** 病例审核通过/状态变化后调用：新科室可能进入广场 */
    public static void evictDepartmentsCache() {
        departmentsCache = null;
        departmentsCacheAt = 0L;
    }

    /** 广场科室列表 TTL 缓存：真病例量小但每次进广场都查库，缓存后最多 5min 延迟（与学生端科室策略一致） */
    private static final long DEPT_CACHE_TTL_MS = 5 * 60 * 1000L;
    private static volatile List<String> departmentsCache;
    private static volatile long departmentsCacheAt;

    private final SpCaseConfigMapper caseMapper;
    private final SysUserMapper userMapper;
    private final ChatSessionMapper sessionMapper;

    /**
     * LIKE 转义声明：配合 escapeLike 使用，防止用户输入 % / _ 被当成通配符。
     * 必须写成 SQL 文本中的双反斜杠：Java "\\\\" -> SQL "ESCAPE '\\'" -> MySQL 解析为单反斜杠转义符。
     * 若只写 "\\"，MySQL 收到 ESCAPE '\' 会把单引号吃掉，直接 1064 语法错误（2026-09-02 实测踩坑）。
     */
    private static final String ESCAPE_CLAUSE = " ESCAPE '\\\\'";

    /**
     * 转义 LIKE 通配符，避免用户输入 "%" 或 "_" 时退化成全表匹配。
     * 顺序敏感：反斜杠必须先转，否则后续插入的转义符会被二次转义。
     */
    private static String escapeLike(String raw) {
        return raw.replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
    }

    @Override
    public PageResult<CaseMarketListVO> list(Integer pageNum, Integer pageSize, String department,
                                             Integer difficulty, String keyword, String sortBy, String order) {
        Page<SpCaseConfig> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<SpCaseConfig> wrapper = new LambdaQueryWrapper<SpCaseConfig>()
                .eq(SpCaseConfig::getIsPublic, true)
                .eq(SpCaseConfig::getAdminAuditStatus, 2)
                .eq(SpCaseConfig::getStatus, 1)
                // 只出正式 BL 编号病例：批量导入的问答式条目（case_no IS NULL、无主诉、
                // 无预置检查）不是可用 SP 病人，进问诊室必然"驴唇不对马嘴"（2026-09-03）。
                .isNotNull(SpCaseConfig::getCaseNo)
                .eq(difficulty != null, SpCaseConfig::getDifficulty, difficulty);

        // 科室模糊匹配：DB 存的是「心血管内科」这类全称，前端 chip 常传「心血管」短名。
        // 用 LIKE 而非等值，否则短名永远 0 命中，表现就是「点了筛选没反应」。
        if (StringUtils.hasText(department)) {
            wrapper.apply("department LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE,
                    escapeLike(department.trim()));
        }

        // 关键字搜索：标题 / 患者画像（内含主诉等结构化字段）/ 知识点标签，三字段 OR。
        // 走服务端而非客户端过滤，否则只能搜到已加载到当前页的十几条。
        if (StringUtils.hasText(keyword)) {
            final String kw = escapeLike(keyword.trim());
            wrapper.and(w -> w
                    .apply("title LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE, kw)
                    .or().apply("patient_profile LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE, kw)
                    .or().apply("knowledge_tags LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE, kw));
        }

        boolean asc = "asc".equalsIgnoreCase(order);
        String sb = (sortBy == null || sortBy.isBlank()) ? "createdAt" : sortBy;
        switch (sb) {
            case "rating", "ratingAvg" -> wrapper.orderBy(true, asc, SpCaseConfig::getRatingAvg);
            case "reference", "referenceCount" -> wrapper.orderBy(true, asc, SpCaseConfig::getReferenceCount);
            case "difficulty" -> wrapper.orderBy(true, asc, SpCaseConfig::getDifficulty);
            case "createdAt" -> wrapper.orderBy(true, asc, SpCaseConfig::getCreatedAt);
            default -> wrapper.orderBy(true, false, SpCaseConfig::getCreatedAt);
        }
        caseMapper.selectPage(page, wrapper);

        List<SpCaseConfig> records = page.getRecords();
        // 批量补全创建者姓名
        List<Long> creatorIds = records.stream()
                .map(SpCaseConfig::getCreatorId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, String> nameMap = new HashMap<>();
        if (!creatorIds.isEmpty()) {
            List<SysUser> users = userMapper.selectList(
                    new LambdaQueryWrapper<SysUser>().in(SysUser::getId, creatorIds));
            for (SysUser u : users) {
                nameMap.put(u.getId(), u.getRealName());
            }
        }

        // 批量补全当前学生的最近问诊状态（已做/进行中/可看报告）→ 前端展示「已做」与续聊
        Map<Long, ChatSession> lastSessionByCase = new HashMap<>();
        try {
            Long currentUserId = UserContext.requireUserId();
            if (currentUserId != null && !records.isEmpty()) {
                List<Long> caseIds = records.stream().map(SpCaseConfig::getId).collect(Collectors.toList());
                List<ChatSession> mine = sessionMapper.selectList(
                        new LambdaQueryWrapper<ChatSession>()
                                .eq(ChatSession::getStudentId, currentUserId)
                                .in(ChatSession::getCaseId, caseIds)
                                .in(ChatSession::getStatus, 0, 1, 2)
                                .orderByDesc(ChatSession::getId));
                for (ChatSession s : mine) {
                    lastSessionByCase.putIfAbsent(s.getCaseId(), s);
                }
            }
        } catch (Exception e) { // noqa - 未登录/非学生等场景降级为不带个人状态
            log.debug("case-market list 跳过个人问诊状态: {}", e.getMessage());
        }

        List<CaseMarketListVO> list = records.stream().map(c -> {
            ChatSession last = lastSessionByCase.get(c.getId());
            return CaseMarketListVO.builder()
                    .id(c.getId())
                    .title(c.getTitle())
                    .department(c.getDepartment())
                    .caseNo(c.getCaseNo())
                    .difficulty(c.getDifficulty())
                    .ratingAvg(c.getRatingAvg())
                    .referenceCount(c.getReferenceCount())
                    .creatorName(nameMap.getOrDefault(c.getCreatorId(), ""))
                    .knowledgeTags(c.getKnowledgeTags())
                    .createdAt(c.getCreatedAt())
                    .lastSessionId(last == null ? null : last.getId())
                    .lastSessionStatus(last == null ? null : last.getStatus())
                    .build();
        }).collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public List<String> departments() {
        List<String> cached = departmentsCache;
        if (cached != null && System.currentTimeMillis() - departmentsCacheAt < DEPT_CACHE_TTL_MS) {
            return cached;
        }
        // 只取科室列，避免把 patient_profile 等大字段拉进内存
        List<SpCaseConfig> rows = caseMapper.selectList(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .select(SpCaseConfig::getDepartment)
                        .eq(SpCaseConfig::getIsPublic, true)
                        .eq(SpCaseConfig::getAdminAuditStatus, 2)
                        .eq(SpCaseConfig::getStatus, 1)
                        // 与 list() 同口径：问答式条目（无 case_no）不参与科室下发
                        .isNotNull(SpCaseConfig::getCaseNo));
        List<String> list = rows.stream()
                .map(SpCaseConfig::getDepartment)
                .filter(StringUtils::hasText)
                .map(String::trim)
                .distinct()
                .sorted()
                .collect(Collectors.toList());
        departmentsCache = list;
        departmentsCacheAt = System.currentTimeMillis();
        return list;
    }

    @Override
    public CaseMarketDetailVO detail(Long caseId) {
        SpCaseConfig c = caseMapper.selectById(caseId);
        if (c == null || !Boolean.TRUE.equals(c.getIsPublic()) ||
                c.getAdminAuditStatus() == null || c.getAdminAuditStatus() != 2 ||
                c.getStatus() == null || c.getStatus() != 1) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        SysUser creator = c.getCreatorId() == null ? null : userMapper.selectById(c.getCreatorId());
        return CaseMarketDetailVO.builder()
                .id(c.getId())
                .title(c.getTitle())
                .department(c.getDepartment())
                .difficulty(c.getDifficulty())
                .patientProfile(c.getPatientProfile())
                .knowledgeTags(c.getKnowledgeTags())
                .referenceCount(c.getReferenceCount())
                .ratingAvg(c.getRatingAvg())
                .creatorName(creator == null ? "" : creator.getRealName())
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long quote(Long caseId) {
        // 仅教师可引用病例
        UserContext.requireRole(1);
        Long teacherId = UserContext.requireUserId();

        SpCaseConfig src = caseMapper.selectById(caseId);
        if (src == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        if (!Boolean.TRUE.equals(src.getIsPublic()) || src.getAdminAuditStatus() == null || src.getAdminAuditStatus() != 2) {
            throw new BizException(ResultCode.CASE_NOT_QUOTABLE);
        }

        // 复制为当前教师的独立副本
        SpCaseConfig copy = new SpCaseConfig();
        copy.setCreatorId(teacherId);
        copy.setSourceCaseId(caseId);
        copy.setTitle(src.getTitle());
        copy.setDepartment(src.getDepartment());
        copy.setDifficulty(src.getDifficulty());
        copy.setPatientProfile(src.getPatientProfile());
        copy.setHiddenDisease(src.getHiddenDisease());
        copy.setStandardPathJson(src.getStandardPathJson());
        copy.setPresetExams(src.getPresetExams());
        copy.setKnowledgeTags(src.getKnowledgeTags());
        copy.setIsPublic(false);
        copy.setReferenceCount(0);
        copy.setRatingAvg(BigDecimal.ZERO);
        copy.setAdminAuditStatus(0);
        copy.setVersion(1);
        copy.setStatus(0);
        caseMapper.insert(copy);

        // 原病例引用量 +1（SQL 原子自增，避免并发竞态）
        caseMapper.incrementReferenceCount(caseId);

        log.info("教师{}引用病例{}为新副本{}", teacherId, caseId, copy.getId());
        return copy.getId();
    }
}
