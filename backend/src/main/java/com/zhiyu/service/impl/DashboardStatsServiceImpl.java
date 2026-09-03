package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.zhiyu.entity.StatDailySummary;
import com.zhiyu.entity.StatOnlineSample;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.StatDailySummaryMapper;
import com.zhiyu.mapper.StatOnlineSampleMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.DashboardStatsService;
import com.zhiyu.service.OnlineStatsService;
import com.zhiyu.vo.TrendPointVO;
import com.zhiyu.vo.UserOverviewVO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 用户数据看板统计实现（PRD 4.13 扩展）
 */
@Service
@RequiredArgsConstructor
public class DashboardStatsServiceImpl implements DashboardStatsService {

    private static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");
    private static final DateTimeFormatter MMDD = DateTimeFormatter.ofPattern("MM-dd");

    private final SysUserMapper userMapper;
    private final StatOnlineSampleMapper sampleMapper;
    private final StatDailySummaryMapper summaryMapper;
    private final OnlineStatsService onlineStatsService;

    @Override
    public UserOverviewVO userOverview() {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();

        Long totalUsers = userMapper.selectCount(null);
        Long studentCount = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, 0));
        Long teacherCount = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>().eq(SysUser::getRole, 1));
        Long todayNewUsers = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>().ge(SysUser::getCreatedAt, todayStart));
        Long todayActiveUsers = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>().ge(SysUser::getLastLoginAt, todayStart));

        long[] online = onlineStatsService.currentSnapshot();

        // 今日峰值：优先取实时快照与采样表最大值
        int todayPeak = samplePeak(LocalDate.now());
        todayPeak = Math.max(todayPeak, (int) online[0]);
        int yesterdayPeak = samplePeak(LocalDate.now().minusDays(1));
        Long yesterdayActive = userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                .ge(SysUser::getLastLoginAt, LocalDate.now().minusDays(1).atStartOfDay())
                .lt(SysUser::getLastLoginAt, todayStart));

        return UserOverviewVO.builder()
                .totalUsers(totalUsers)
                .studentCount(studentCount)
                .teacherCount(teacherCount)
                .todayNewUsers(todayNewUsers)
                .todayActiveUsers(todayActiveUsers)
                .currentOnline(online[0])
                .currentOnlineStudents(online[1])
                .currentOnlineTeachers(online[2])
                .todayPeakOnline(todayPeak)
                .yesterdayPeakOnline(yesterdayPeak)
                .yesterdayActiveUsers(yesterdayActive)
                .build();
    }

    @Override
    public List<TrendPointVO> onlineTrend(LocalDate date) {
        LocalDateTime dayStart = date.atStartOfDay();
        LocalDateTime dayEnd = date.atTime(LocalTime.MAX);
        List<StatOnlineSample> samples = sampleMapper.selectList(
                new LambdaQueryWrapper<StatOnlineSample>()
                        .ge(StatOnlineSample::getSampleTime, dayStart)
                        .le(StatOnlineSample::getSampleTime, dayEnd)
                        .orderByAsc(StatOnlineSample::getSampleTime));

        List<TrendPointVO> points = new ArrayList<>();
        for (StatOnlineSample s : samples) {
            points.add(TrendPointVO.builder()
                    .label(s.getSampleTime().format(HHMM))
                    .total(nz(s.getOnlineCount()))
                    .students(nz(s.getStudentCount()))
                    .teachers(nz(s.getTeacherCount()))
                    .build());
        }
        return points;
    }

    @Override
    public List<TrendPointVO> registerTrend(int days) {
        days = clampDays(days);
        LocalDate start = LocalDate.now().minusDays(days - 1L);

        // 按注册日期分组统计（逻辑删除由 @TableLogic 自动附加）
        QueryWrapper<SysUser> qw = new QueryWrapper<>();
        qw.select("DATE(created_at) AS d", "COUNT(*) AS cnt")
                .ge("created_at", start.atStartOfDay())
                .groupBy("DATE(created_at)");
        List<Map<String, Object>> rows = userMapper.selectMaps(qw);
        Map<LocalDate, Long> countByDate = new HashMap<>();
        for (Map<String, Object> row : rows) {
            LocalDate d = toLocalDate(row.get("d"));
            Object cnt = row.get("cnt");
            if (d != null && cnt != null) {
                countByDate.put(d, ((Number) cnt).longValue());
            }
        }

        // 补齐连续日期，缺失的天填 0
        List<TrendPointVO> points = new ArrayList<>();
        for (int i = 0; i < days; i++) {
            LocalDate d = start.plusDays(i);
            points.add(TrendPointVO.builder()
                    .label(d.format(MMDD))
                    .newUsers(countByDate.getOrDefault(d, 0L).intValue())
                    .build());
        }
        return points;
    }

    @Override
    public List<TrendPointVO> activeTrend(int days) {
        days = clampDays(days);
        LocalDate today = LocalDate.now();
        LocalDate start = today.minusDays(days - 1L);

        // 已汇总的历史数据
        List<StatDailySummary> summaries = summaryMapper.selectList(
                new LambdaQueryWrapper<StatDailySummary>()
                        .ge(StatDailySummary::getStatDate, start)
                        .lt(StatDailySummary::getStatDate, today));
        Map<LocalDate, StatDailySummary> byDate = new HashMap<>();
        for (StatDailySummary s : summaries) {
            byDate.put(s.getStatDate(), s);
        }

        List<TrendPointVO> points = new ArrayList<>();
        for (int i = 0; i < days; i++) {
            LocalDate d = start.plusDays(i);
            if (d.equals(today)) {
                // 当日实时计算
                LocalDateTime dayStart = today.atStartOfDay();
                Long dau = userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                        .ge(SysUser::getLastLoginAt, dayStart));
                int peak = Math.max(samplePeak(today),
                        (int) onlineStatsService.currentSnapshot()[0]);
                points.add(TrendPointVO.builder()
                        .label(d.format(MMDD))
                        .total(dau.intValue())
                        .newUsers(0)
                        .students(peak)
                        .build());
            } else {
                StatDailySummary s = byDate.get(d);
                points.add(TrendPointVO.builder()
                        .label(d.format(MMDD))
                        .total(s == null ? 0 : nz(s.getDau()))
                        .students(s == null ? 0 : nz(s.getPeakOnline()))
                        .newUsers(0)
                        .build());
            }
        }
        return points;
    }

    // ==================== 内部工具 ====================

    private int samplePeak(LocalDate date) {
        QueryWrapper<StatOnlineSample> qw = new QueryWrapper<>();
        qw.select("COALESCE(MAX(online_count), 0) AS peak")
                .ge("sample_time", date.atStartOfDay())
                .le("sample_time", date.atTime(LocalTime.MAX));
        List<Map<String, Object>> rows = sampleMapper.selectMaps(qw);
        if (rows != null && !rows.isEmpty() && rows.get(0).get("peak") != null) {
            return ((Number) rows.get(0).get("peak")).intValue();
        }
        return 0;
    }

    private int nz(Integer v) {
        return v == null ? 0 : v;
    }

    private int clampDays(int days) {
        if (days <= 0) {
            return 30;
        }
        return Math.min(days, 90);
    }

    private LocalDate toLocalDate(Object o) {
        if (o == null) {
            return null;
        }
        if (o instanceof LocalDate d) {
            return d;
        }
        if (o instanceof LocalDateTime dt) {
            return dt.toLocalDate();
        }
        if (o instanceof java.sql.Date d) {
            return d.toLocalDate();
        }
        try {
            return LocalDate.parse(o.toString());
        } catch (Exception e) {
            return null;
        }
    }
}
