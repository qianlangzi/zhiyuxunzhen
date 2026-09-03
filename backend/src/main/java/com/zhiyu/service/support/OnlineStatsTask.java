package com.zhiyu.service.support;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.entity.StatDailySummary;
import com.zhiyu.entity.StatOnlineSample;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.StatDailySummaryMapper;
import com.zhiyu.mapper.StatOnlineSampleMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.OnlineStatsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/**
 * 用户数据看板定时任务：
 *   1) 每 5 分钟采样在线人数 → stat_online_sample（供"今日在线走势"折线图）
 *   2) 每日凌晨汇总前一天数据 → stat_daily_summary（供"近 30 天活跃/新增"折线图）
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OnlineStatsTask {

    private final OnlineStatsService onlineStatsService;
    private final StatOnlineSampleMapper sampleMapper;
    private final StatDailySummaryMapper summaryMapper;
    private final SysUserMapper userMapper;

    /** 每 5 分钟采样一次在线人数 */
    @Scheduled(fixedDelay = 5 * 60 * 1000, initialDelay = 30 * 1000)
    public void sampleOnline() {
        try {
            long[] snap = onlineStatsService.currentSnapshot();
            LocalDateTime now = LocalDateTime.now().withSecond(0).withNano(0);
            StatOnlineSample sample = new StatOnlineSample();
            sample.setSampleTime(now);
            sample.setOnlineCount((int) snap[0]);
            sample.setStudentCount((int) snap[1]);
            sample.setTeacherCount((int) snap[2]);
            try {
                sampleMapper.insert(sample);
            } catch (org.springframework.dao.DuplicateKeyException e) {
                // 同一分钟重复采样时覆盖
                StatOnlineSample update = new StatOnlineSample();
                update.setOnlineCount(sample.getOnlineCount());
                update.setStudentCount(sample.getStudentCount());
                update.setTeacherCount(sample.getTeacherCount());
                sampleMapper.update(update, new LambdaQueryWrapper<StatOnlineSample>()
                        .eq(StatOnlineSample::getSampleTime, now));
            }
        } catch (Exception e) {
            log.warn("在线人数采样失败: {}", e.getMessage());
        }
    }

    /** 每日凌晨 00:05 汇总前一天数据 */
    @Scheduled(cron = "0 5 0 * * ?")
    public void summarizeYesterday() {
        summarize(LocalDate.now().minusDays(1));
    }

    /**
     * 汇总指定日期数据（幂等，存在则覆盖）
     */
    public void summarize(LocalDate date) {
        try {
            LocalDateTime dayStart = date.atStartOfDay();
            LocalDateTime dayEnd = date.atTime(LocalTime.MAX);

            // DAU：当日有登录的用户数
            Long dau = userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                    .ge(SysUser::getLastLoginAt, dayStart)
                    .le(SysUser::getLastLoginAt, dayEnd));

            // 新增注册
            Long newUsers = userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                    .ge(SysUser::getCreatedAt, dayStart)
                    .le(SysUser::getCreatedAt, dayEnd));

            // 累计注册（含当日）
            Long totalUsers = userMapper.selectCount(new LambdaQueryWrapper<SysUser>()
                    .le(SysUser::getCreatedAt, dayEnd));

            // 峰值/平均在线（来自采样表）
            var samples = sampleMapper.selectList(new LambdaQueryWrapper<StatOnlineSample>()
                    .ge(StatOnlineSample::getSampleTime, dayStart)
                    .le(StatOnlineSample::getSampleTime, dayEnd));
            int peak = 0;
            int sum = 0;
            for (var s : samples) {
                int c = s.getOnlineCount() == null ? 0 : s.getOnlineCount();
                peak = Math.max(peak, c);
                sum += c;
            }
            int avg = samples.isEmpty() ? 0 : sum / samples.size();

            StatDailySummary summary = summaryMapper.selectOne(
                    new LambdaQueryWrapper<StatDailySummary>()
                            .eq(StatDailySummary::getStatDate, date));
            if (summary == null) {
                summary = new StatDailySummary();
                summary.setStatDate(date);
            }
            summary.setDau(dau.intValue());
            summary.setNewUsers(newUsers.intValue());
            summary.setTotalUsers(totalUsers.intValue());
            summary.setPeakOnline(peak);
            summary.setAvgOnline(avg);
            if (summary.getId() == null) {
                summaryMapper.insert(summary);
            } else {
                summaryMapper.updateById(summary);
            }
            log.info("每日运营汇总完成: {} dau={} newUsers={} peak={}", date, dau, newUsers, peak);
        } catch (Exception e) {
            log.warn("每日运营汇总失败({}): {}", date, e.getMessage());
        }
    }
}
