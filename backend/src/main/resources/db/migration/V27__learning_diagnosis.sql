-- ============================================================
-- V27: 教师学情诊断报告（P1-1）
-- ------------------------------------------------------------
-- learning_diagnosis 持久化教师生成的班级学情诊断报告：
--   生成时基于真实聚合统计（作业完成率/平均分/OSCE 维度/共性错题）
--   + AI 归纳，快照写入 summary_json（统计 + AI 结果），
--   支持历史查看/删除；AI 不可用时代只保留统计快照（source=RULE）。
-- ============================================================

CREATE TABLE IF NOT EXISTS learning_diagnosis (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    teacher_id BIGINT NOT NULL COMMENT '生成报告的教师',
    class_id BIGINT NULL COMMENT '报告范围：NULL=全体学生',
    class_name VARCHAR(64) NOT NULL DEFAULT '' COMMENT '范围名称（班级名/全体学生）',
    title VARCHAR(128) NOT NULL DEFAULT '' COMMENT '报告标题',
    summary_json JSON NULL COMMENT '报告内容快照（统计+AI归纳）',
    source VARCHAR(16) NOT NULL DEFAULT 'AI' COMMENT '内容来源 AI/RULE',
    status VARCHAR(16) NOT NULL DEFAULT 'SUCCESS' COMMENT 'SUCCESS/DEGRADED',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_teacher_created (teacher_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='教师学情诊断报告';