package com.zhiyu.service.impl;

import com.zhiyu.service.OnlineStatsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.Set;

/**
 * 在线用户统计实现（用户数据看板）
 *
 * 数据结构：Redis ZSET，key = online:users
 *   member = "userId:role"（role 用于分角色统计）
 *   score  = 最后活跃时间戳（epoch millis）
 *
 * 在线判定：最后活跃时间在 ONLINE_WINDOW_MINUTES 分钟内。
 * touch 时顺带清理窗口外成员，保证 ZSET 不无限膨胀。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OnlineStatsServiceImpl implements OnlineStatsService {

    private static final String KEY_ONLINE_USERS = "online:users";

    private final StringRedisTemplate redisTemplate;

    @Override
    public void touch(Long userId, Integer role) {
        try {
            long now = System.currentTimeMillis();
            String member = userId + ":" + (role == null ? -1 : role);
            redisTemplate.opsForZSet().add(KEY_ONLINE_USERS, member, now);
            // 清理窗口外成员（按 score 范围删除）
            redisTemplate.opsForZSet().removeRangeByScore(
                    KEY_ONLINE_USERS, 0, now - ONLINE_WINDOW_MINUTES * 60_000L);
        } catch (Exception e) {
            // Redis 故障不影响业务
            log.debug("在线心跳写入失败: {}", e.getMessage());
        }
    }

    @Override
    public long[] currentSnapshot() {
        try {
            long windowStart = System.currentTimeMillis() - ONLINE_WINDOW_MINUTES * 60_000L;
            // 清理后再统计，避免把离线成员计入
            redisTemplate.opsForZSet().removeRangeByScore(KEY_ONLINE_USERS, 0, windowStart);
            Set<String> members = redisTemplate.opsForZSet().range(KEY_ONLINE_USERS, 0, -1);
            long total = 0, students = 0, teachers = 0;
            if (members != null) {
                total = members.size();
                for (String m : members) {
                    int idx = m.lastIndexOf(':');
                    int role = idx >= 0 ? parseIntSafe(m.substring(idx + 1)) : -1;
                    if (role == 0) {
                        students++;
                    } else if (role == 1) {
                        teachers++;
                    }
                }
            }
            return new long[]{total, students, teachers};
        } catch (Exception e) {
            log.debug("在线人数统计失败: {}", e.getMessage());
            return new long[]{0, 0, 0};
        }
    }

    private int parseIntSafe(String s) {
        try {
            return Integer.parseInt(s.trim());
        } catch (NumberFormatException e) {
            return -1;
        }
    }
}
