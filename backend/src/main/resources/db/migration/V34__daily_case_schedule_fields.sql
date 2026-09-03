-- ============================================================
-- 每日一例自动化调度：病例表增加 is_daily / daily_date 字段
-- is_daily 标记该病例是否被选为每日一例；daily_date 记录最近一次选中的日期。
-- 配合 daily_case_schedule 排期表，自动排期时仅抽取"未使用"（从未进排期表）的病例。
-- ============================================================

ALTER TABLE sp_case_config
    ADD COLUMN is_daily TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否被选为每日一例:0否 1是' AFTER admin_audit_status,
    ADD COLUMN daily_date DATE NULL COMMENT '最近一次被选为每日一例的日期' AFTER is_daily;

ALTER TABLE sp_case_config
    ADD INDEX idx_daily (is_daily, daily_date);