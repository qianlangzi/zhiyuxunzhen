-- ============================================================
-- V28: 用户反馈与试用埋点（P2-3 真实用户数据）
-- ------------------------------------------------------------
-- student_feedback：学生内嵌「体验反馈」入口，收集功能满意度与建议，
--   支撑大赛「用户认可度 / 真实用户数据」评分。
-- user_action_log：关键动作轻量埋点（如 companion_open / learning_path_generate），
--   可导出真实试用记录与完成率/延迟分析。
-- ============================================================

CREATE TABLE IF NOT EXISTS student_feedback (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_id BIGINT NOT NULL COMMENT '学生ID',
    category VARCHAR(32) NOT NULL DEFAULT 'general' COMMENT '功能/学习内容/使用问题/建议/其他',
    rating TINYINT NOT NULL DEFAULT 0 COMMENT '满意度评分 1-5，0=未评分',
    content VARCHAR(1000) NOT NULL DEFAULT '' COMMENT '反馈内容',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '0待处理 1已处理',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_student_time (student_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='学生反馈';

CREATE TABLE IF NOT EXISTS user_action_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL COMMENT '用户ID',
    role VARCHAR(16) NOT NULL DEFAULT 'student' COMMENT 'student/teacher',
    action VARCHAR(64) NOT NULL DEFAULT '' COMMENT '动作编码，如 companion_open/learning_path_generate',
    detail VARCHAR(500) NOT NULL DEFAULT '' COMMENT '动作描述/关键摘要',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_user_time (user_id, created_at),
    KEY idx_action_time (action, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户关键动作日志（试用埋点）';
