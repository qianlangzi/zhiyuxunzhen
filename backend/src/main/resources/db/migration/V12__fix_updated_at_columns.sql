-- ============================================================
-- V12: 修复 V11 新表缺失 updated_at 列（BaseEntity 审计字段要求）
-- ------------------------------------------------------------
-- lesson_plan 已在 V11 建表时包含 updated_at；其余 4 张表补齐。
-- ============================================================

ALTER TABLE lesson_material
    ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        COMMENT '更新时间' AFTER created_at;

ALTER TABLE lesson_publish
    ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        COMMENT '更新时间' AFTER created_at;

ALTER TABLE student_alert
    ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        COMMENT '更新时间' AFTER created_at;

ALTER TABLE sys_notification
    ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        COMMENT '更新时间' AFTER created_at;
