-- 教材入库自动对账：区分自动重试与管理员手动触发
-- 用途：
--   ingest_auto_retry_count   自动对账（定时任务）累计重试次数，独立于管理员手动计数 ingest_retry_count，
--                             用于「最大自动重试次数」上限控制，管理员手动重试会重置该计数给新的重试预算。
--   ingest_trigger_source     最近一次入库触发来源：1管理员手动 2定时自动对账，供管理端页面识别任务由谁触发。
-- 建立索引：按 (ingest_status, last_ingest_at) 加速「处理中超时」扫描——对账任务每 10 分钟扫一次该条件。
ALTER TABLE textbook
    ADD COLUMN ingest_auto_retry_count INT NOT NULL DEFAULT 0
        COMMENT '自动对账重试次数（定时任务触发，独立于管理员手动计数）' AFTER ingest_retry_count,
    ADD COLUMN ingest_trigger_source TINYINT NOT NULL DEFAULT 1
        COMMENT '最近一次入库触发来源:1管理员手动 2定时自动对账' AFTER ingest_auto_retry_count,
    ADD INDEX idx_textbook_ingest_pending (ingest_status, last_ingest_at);