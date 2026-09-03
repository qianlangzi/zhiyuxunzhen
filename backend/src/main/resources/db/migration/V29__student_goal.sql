-- ============================================================
-- V29: 学生学习目标（P2-1 学习档案/目标管理）
-- ------------------------------------------------------------
-- student_goal：学生在「学习档案」页设定个性化目标（标题 + 量化指标 + 目标日期），
--   支撑「个性化与自适应」评分点，数据真实持久。
-- ============================================================

CREATE TABLE IF NOT EXISTS student_goal (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_id BIGINT NOT NULL COMMENT '学生ID',
    title VARCHAR(200) NOT NULL DEFAULT '' COMMENT '目标标题',
    target_metric VARCHAR(100) NOT NULL DEFAULT '' COMMENT '量化指标，如 OSCE 均分≥85',
    target_date DATE NULL COMMENT '目标截止日期',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '0进行中 1已完成',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_student_time (student_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='学生学习目标';
