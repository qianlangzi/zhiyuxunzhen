-- 用户数据看板（PRD 4.13 扩展）：在线人数采样与每日运营汇总
-- 1) 每 5 分钟采样一次在线人数，供"今日在线走势"折线图使用
CREATE TABLE IF NOT EXISTS stat_online_sample (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sample_time DATETIME NOT NULL COMMENT '采样时间（截断到分钟）',
    online_count INT NOT NULL DEFAULT 0 COMMENT '当前在线总人数（5分钟活跃窗口）',
    student_count INT NOT NULL DEFAULT 0 COMMENT '其中学生数',
    teacher_count INT NOT NULL DEFAULT 0 COMMENT '其中教师数',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sample_time (sample_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='在线人数采样表';

-- 2) 每日运营汇总，供"近 30 天活跃/新增"折线图使用
CREATE TABLE IF NOT EXISTS stat_daily_summary (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    stat_date DATE NOT NULL COMMENT '统计日期',
    dau INT NOT NULL DEFAULT 0 COMMENT '日活跃用户数（当日有登录）',
    new_users INT NOT NULL DEFAULT 0 COMMENT '当日新增注册数',
    total_users INT NOT NULL DEFAULT 0 COMMENT '截至当日累计注册数',
    peak_online INT NOT NULL DEFAULT 0 COMMENT '当日峰值在线人数',
    avg_online INT NOT NULL DEFAULT 0 COMMENT '当日平均在线人数',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_stat_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='每日运营汇总表';
