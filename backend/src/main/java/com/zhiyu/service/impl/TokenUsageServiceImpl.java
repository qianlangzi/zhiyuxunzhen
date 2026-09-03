package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.LlmModelQuota;
import com.zhiyu.entity.LlmTokenUsage;
import com.zhiyu.mapper.LlmModelQuotaMapper;
import com.zhiyu.mapper.LlmTokenUsageMapper;
import com.zhiyu.service.TokenUsageService;
import com.zhiyu.service.dto.TokenQuotaDTO;
import com.zhiyu.service.dto.internal.TokenUsageReportDTO;
import com.zhiyu.vo.TokenOverviewVO;
import com.zhiyu.vo.TokenQuotaAlertVO;
import com.zhiyu.vo.TokenQuotaVO;
import com.zhiyu.vo.TokenRankVO;
import com.zhiyu.vo.TokenTrendPointVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Token 用量统计与配额管理（V39）
 *
 * <p>聚合查询统一走 MyBatis Plus 的 selectMaps + groupBy，
 * 避免把全量流水拉到内存里做统计。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TokenUsageServiceImpl implements TokenUsageService {

    private final LlmTokenUsageMapper usageMapper;
    private final LlmModelQuotaMapper quotaMapper;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    // ==================== 上报 ====================

    @Override
    public void report(TokenUsageReportDTO dto) {
        if (dto == null || !StringUtils.hasText(dto.getModel())) {
            throw new BizException(ResultCode.BAD_REQUEST, "上报数据缺少模型标识");
        }
        int prompt = nvl(dto.getPromptTokens());
        int completion = nvl(dto.getCompletionTokens());
        // total 缺失时用 prompt + completion 兜底，保证统计不丢量
        int total = dto.getTotalTokens() != null && dto.getTotalTokens() > 0
                ? dto.getTotalTokens()
                : prompt + completion;

        LlmTokenUsage entity = new LlmTokenUsage();
        entity.setTraceId(dto.getTraceId());
        entity.setScene(StringUtils.hasText(dto.getScene()) ? dto.getScene() : "unknown");
        entity.setCapability(StringUtils.hasText(dto.getCapability()) ? dto.getCapability() : "LLM");
        entity.setModel(dto.getModel().trim());
        entity.setPromptTokens(prompt);
        entity.setCompletionTokens(completion);
        entity.setTotalTokens(total);
        entity.setLatencyMs(nvl(dto.getLatencyMs()));
        entity.setStudentId(dto.getStudentId());
        entity.setSessionId(dto.getSessionId());
        entity.setSuccess(dto.getSuccess() == null ? Boolean.TRUE : dto.getSuccess());
        entity.setIsStream(dto.getIsStream() == null ? Boolean.FALSE : dto.getIsStream());
        usageMapper.insert(entity);
    }

    // ==================== 总览 ====================

    @Override
    public TokenOverviewVO overview() {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime monthStart = LocalDate.now().withDayOfMonth(1).atStartOfDay();

        Long todayTokens = sumTokens(todayStart, null);
        Long monthTokens = sumTokens(monthStart, null);
        Long totalTokens = sumTokens(null, null);
        Long todayCalls = countCalls(todayStart, null);
        Long monthCalls = countCalls(monthStart, null);
        Long monthFailed = usageMapper.selectCount(new LambdaQueryWrapper<LlmTokenUsage>()
                .ge(LlmTokenUsage::getCreatedAt, monthStart)
                .eq(LlmTokenUsage::getSuccess, false));

        // 本月按模型分组用量，供配额匹配使用（一次查询，避免逐模型 COUNT）
        Map<String, Long> usedByModel = sumByColumn("model", monthStart, null);

        // 配额与告警
        List<LlmModelQuota> quotas = quotaMapper.selectList(
                new LambdaQueryWrapper<LlmModelQuota>().eq(LlmModelQuota::getStatus, 1));

        long monthQuota = 0;
        long quotaCoveredUsed = 0;
        List<TokenQuotaAlertVO> alerts = new ArrayList<>();
        for (LlmModelQuota q : quotas) {
            long quota = q.getMonthlyQuota() == null ? 0L : q.getMonthlyQuota();
            if (quota <= 0) {
                continue; // 0 = 不限制，不纳入配额覆盖率计算
            }
            monthQuota += quota;
            long used = usedByModel.getOrDefault(q.getModel(), 0L);
            quotaCoveredUsed += used;
            int percent = percent(used, quota);
            int warnPercent = q.getWarnPercent() == null ? 80 : q.getWarnPercent();
            if (percent >= 100) {
                alerts.add(TokenQuotaAlertVO.builder().model(q.getModel()).usedTokens(used)
                        .monthlyQuota(quota).usedPercent(percent).level("exceeded").build());
            } else if (percent >= warnPercent) {
                alerts.add(TokenQuotaAlertVO.builder().model(q.getModel()).usedTokens(used)
                        .monthlyQuota(quota).usedPercent(percent).level("warning").build());
            }
        }
        alerts.sort(Comparator.comparingInt(TokenQuotaAlertVO::getUsedPercent).reversed());

        return TokenOverviewVO.builder()
                .todayTokens(todayTokens)
                .monthTokens(monthTokens)
                .totalTokens(totalTokens)
                .todayCalls(todayCalls)
                .monthCalls(monthCalls)
                .avgLatencyMs(avgLatency(monthStart))
                .monthFailedCalls(monthFailed)
                .monthQuota(monthQuota)
                // 未配置任何有效配额时不展示进度条
                .monthUsedPercent(monthQuota > 0 ? percent(quotaCoveredUsed, monthQuota) : null)
                .alerts(alerts)
                .build();
    }

    // ==================== 趋势 ====================

    @Override
    public List<TokenTrendPointVO> trend(int days) {
        int n = (days <= 0 || days > 365) ? 30 : days;
        LocalDate start = LocalDate.now().minusDays(n - 1);

        List<Map<String, Object>> rows = usageMapper.selectMaps(
                new QueryWrapper<LlmTokenUsage>()
                        .select("DATE_FORMAT(created_at, '%Y-%m-%d') AS d",
                                "SUM(total_tokens) AS tt",
                                "SUM(prompt_tokens) AS pt",
                                "SUM(completion_tokens) AS ct",
                                "COUNT(*) AS c")
                        .ge("created_at", start.atStartOfDay())
                        .groupBy("d")
                        .orderByAsc("d"));

        // 数据库里已有日期的数据
        Map<String, TokenTrendPointVO> byDate = new LinkedHashMap<>();
        for (Map<String, Object> row : rows) {
            String d = str(row.get("d"));
            if (d == null) {
                continue;
            }
            byDate.put(d, TokenTrendPointVO.builder()
                    .label(d)
                    .totalTokens(lng(row.get("tt")))
                    .promptTokens(lng(row.get("pt")))
                    .completionTokens(lng(row.get("ct")))
                    .calls(lng(row.get("c")))
                    .build());
        }

        // 补零：没有调用的日期也要出现在折线上，否则趋势图会失真
        List<TokenTrendPointVO> result = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            String d = start.plusDays(i).format(DATE_FMT);
            TokenTrendPointVO point = byDate.get(d);
            result.add(point != null ? point : TokenTrendPointVO.builder()
                    .label(d).totalTokens(0L).promptTokens(0L).completionTokens(0L).calls(0L).build());
        }
        return result;
    }

    // ==================== 排行 ====================

    @Override
    public List<TokenRankVO> rank(String dimension, int days) {
        // 白名单：防止把用户输入直接拼进 SQL 片段
        String col = "scene".equalsIgnoreCase(dimension) ? "scene" : "model";
        int n = (days <= 0 || days > 365) ? 30 : days;
        LocalDate start = LocalDate.now().minusDays(n - 1);

        List<Map<String, Object>> rows = usageMapper.selectMaps(
                new QueryWrapper<LlmTokenUsage>()
                        .select(col + " AS name",
                                "SUM(total_tokens) AS tt",
                                "SUM(prompt_tokens) AS pt",
                                "SUM(completion_tokens) AS ct",
                                "COUNT(*) AS c",
                                "AVG(latency_ms) AS ltm")
                        .ge("created_at", start.atStartOfDay())
                        .groupBy("name")
                        .orderByDesc("tt"));

        List<TokenRankVO> list = new ArrayList<>(rows.size());
        for (Map<String, Object> row : rows) {
            String name = str(row.get("name"));
            if (name == null) {
                continue;
            }
            list.add(TokenRankVO.builder()
                    .name(name)
                    .totalTokens(lng(row.get("tt")))
                    .promptTokens(lng(row.get("pt")))
                    .completionTokens(lng(row.get("ct")))
                    .calls(lng(row.get("c")))
                    .avgLatencyMs(lng(row.get("ltm")))
                    .build());
        }

        long grand = list.stream().mapToLong(v -> v.getTotalTokens() == null ? 0L : v.getTotalTokens()).sum();
        if (grand > 0) {
            for (TokenRankVO v : list) {
                v.setPercent(percent(v.getTotalTokens() == null ? 0L : v.getTotalTokens(), grand));
            }
        } else {
            for (TokenRankVO v : list) {
                v.setPercent(0);
            }
        }
        return list;
    }

    // ==================== 配额 ====================

    @Override
    public List<TokenQuotaVO> listQuota() {
        LocalDateTime monthStart = LocalDate.now().withDayOfMonth(1).atStartOfDay();
        Map<String, Long> usedByModel = sumByColumn("model", monthStart, null);

        List<LlmModelQuota> quotas = quotaMapper.selectList(
                new LambdaQueryWrapper<LlmModelQuota>().orderByDesc(LlmModelQuota::getUpdatedAt));

        List<TokenQuotaVO> list = new ArrayList<>(quotas.size());
        for (LlmModelQuota q : quotas) {
            long quota = q.getMonthlyQuota() == null ? 0L : q.getMonthlyQuota();
            long used = usedByModel.getOrDefault(q.getModel(), 0L);
            int usedPercent = quota > 0 ? percent(used, quota) : 0;
            int warnPercent = q.getWarnPercent() == null ? 80 : q.getWarnPercent();
            list.add(TokenQuotaVO.builder()
                    .id(q.getId())
                    .model(q.getModel())
                    .monthlyQuota(quota)
                    .warnPercent(warnPercent)
                    .status(q.getStatus())
                    .remark(q.getRemark())
                    .usedTokens(used)
                    .usedPercent(quota > 0 ? usedPercent : null)
                    .warning(quota > 0 && usedPercent >= warnPercent && usedPercent < 100)
                    .exceeded(quota > 0 && usedPercent >= 100)
                    .build());
        }
        return list;
    }

    @Override
    public void saveQuota(TokenQuotaDTO dto) {
        if (dto == null || !StringUtils.hasText(dto.getModel())) {
            throw new BizException(ResultCode.BAD_REQUEST, "模型标识不能为空");
        }
        String model = dto.getModel().trim();

        LlmModelQuota entity = new LlmModelQuota();
        entity.setModel(model);
        entity.setMonthlyQuota(dto.getMonthlyQuota() == null ? 0L : dto.getMonthlyQuota());
        entity.setWarnPercent(dto.getWarnPercent() == null ? 80 : dto.getWarnPercent());
        entity.setStatus(dto.getStatus() == null ? 1 : dto.getStatus());
        entity.setRemark(dto.getRemark());

        if (dto.getId() != null) {
            entity.setId(dto.getId());
            if (quotaMapper.updateById(entity) == 0) {
                throw new BizException(ResultCode.NOT_FOUND, "配额记录不存在");
            }
            return;
        }

        // 新增：同模型只允许一条，重复则视为更新
        LlmModelQuota exists = quotaMapper.selectOne(
                new LambdaQueryWrapper<LlmModelQuota>().eq(LlmModelQuota::getModel, model));
        if (exists != null) {
            entity.setId(exists.getId());
            quotaMapper.updateById(entity);
            return;
        }
        quotaMapper.insert(entity);
    }

    @Override
    public void deleteQuota(Long id) {
        if (id == null) {
            throw new BizException(ResultCode.BAD_REQUEST, "配额 ID 不能为空");
        }
        if (quotaMapper.deleteById(id) == 0) {
            throw new BizException(ResultCode.NOT_FOUND, "配额记录不存在");
        }
    }

    // ==================== 私有工具 ====================

    private Long sumTokens(LocalDateTime from, LocalDateTime to) {
        List<Map<String, Object>> rows = usageMapper.selectMaps(
                new QueryWrapper<LlmTokenUsage>().select("IFNULL(SUM(total_tokens),0) AS s")
                        .ge(from != null, "created_at", from)
                        .lt(to != null, "created_at", to));
        return rows.isEmpty() ? 0L : lng(rows.get(0).get("s"));
    }

    private Long countCalls(LocalDateTime from, LocalDateTime to) {
        LambdaQueryWrapper<LlmTokenUsage> qw = new LambdaQueryWrapper<>();
        if (from != null) {
            qw.ge(LlmTokenUsage::getCreatedAt, from);
        }
        if (to != null) {
            qw.lt(LlmTokenUsage::getCreatedAt, to);
        }
        return usageMapper.selectCount(qw);
    }

    private Long avgLatency(LocalDateTime from) {
        List<Map<String, Object>> rows = usageMapper.selectMaps(
                new QueryWrapper<LlmTokenUsage>().select("IFNULL(AVG(latency_ms),0) AS a")
                        .ge(from != null, "created_at", from));
        if (rows.isEmpty()) {
            return 0L;
        }
        Object v = rows.get(0).get("a");
        if (v == null) {
            return 0L;
        }
        // MySQL AVG 返回 BigDecimal，四舍五入到整数毫秒
        return v instanceof BigDecimal bd ? bd.longValue() : lng(v);
    }

    /** 按指定列分组统计用量，返回 列名 → 总 token */
    private Map<String, Long> sumByColumn(String column, LocalDateTime from, LocalDateTime to) {
        String col = "scene".equalsIgnoreCase(column) ? "scene" : "model";
        List<Map<String, Object>> rows = usageMapper.selectMaps(
                new QueryWrapper<LlmTokenUsage>()
                        .select(col + " AS name", "SUM(total_tokens) AS tt")
                        .ge(from != null, "created_at", from)
                        .lt(to != null, "created_at", to)
                        .groupBy("name"));

        Map<String, Long> map = new HashMap<>(Math.max(16, rows.size() * 2));
        for (Map<String, Object> row : rows) {
            String name = str(row.get("name"));
            if (name != null) {
                map.put(name, lng(row.get("tt")));
            }
        }
        return map;
    }

    private static int percent(long used, long total) {
        if (total <= 0) {
            return 0;
        }
        double p = used * 100.0 / total;
        return (int) Math.min(999, Math.round(p));
    }

    private static int nvl(Integer v) {
        return v == null || v < 0 ? 0 : v;
    }

    private static Long lng(Object v) {
        if (v == null) {
            return 0L;
        }
        return v instanceof Number n ? n.longValue() : 0L;
    }

    private static String str(Object v) {
        if (v == null) {
            return null;
        }
        String s = String.valueOf(v).trim();
        return s.isEmpty() ? null : s;
    }
}
