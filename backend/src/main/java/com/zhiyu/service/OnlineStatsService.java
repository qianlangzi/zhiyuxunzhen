package com.zhiyu.service;

/**
 * 在线用户统计服务（用户数据看板）
 * 基于 Redis ZSET 维护 5 分钟滑动窗口的在线会话。
 */
public interface OnlineStatsService {

    /** 在线判定窗口（分钟）：该时间内有任何请求即视为在线 */
    long ONLINE_WINDOW_MINUTES = 5;

    /**
     * 用户在线心跳：每次携带有效 JWT 的请求调用。
     * Redis 故障时静默降级，不影响正常业务。
     */
    void touch(Long userId, Integer role);

    /**
     * 当前在线快照。
     *
     * @return [0]=总在线数 [1]=学生数 [2]=教师数；Redis 故障时返回 {0,0,0}
     */
    long[] currentSnapshot();
}
