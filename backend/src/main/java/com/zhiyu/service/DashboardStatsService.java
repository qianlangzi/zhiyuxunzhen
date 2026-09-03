package com.zhiyu.service;

import com.zhiyu.vo.TrendPointVO;
import com.zhiyu.vo.UserOverviewVO;

import java.time.LocalDate;
import java.util.List;

/**
 * 用户数据看板统计服务（PRD 4.13 扩展）
 */
public interface DashboardStatsService {

    /** 用户总览：注册/活跃/在线 */
    UserOverviewVO userOverview();

    /** 某日在线人数走势（按 5 分钟采样点） */
    List<TrendPointVO> onlineTrend(LocalDate date);

    /** 近 N 天每日新增注册趋势 */
    List<TrendPointVO> registerTrend(int days);

    /** 近 N 天每日活跃(DAU)与峰值在线趋势 */
    List<TrendPointVO> activeTrend(int days);
}
