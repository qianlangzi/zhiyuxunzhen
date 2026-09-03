-- 教材入库任务 ID 与重试计数
-- 用途：
--   ingestion_id     记录 AI 中台最近一次入库任务 ID（回调携带，后端据此丢弃旧任务迟到回调，防止乱序覆盖）
--   ingest_retry_count 统计管理端累计触发入库次数（含重试/重新入库），供管理端诊断
ALTER TABLE textbook
    ADD COLUMN ingestion_id VARCHAR(64) NULL
        COMMENT 'AI 中台最近一次入库任务 ID（防止旧任务回调污染新任务）' AFTER last_ingest_at,
    ADD COLUMN ingest_retry_count INT NOT NULL DEFAULT 0
        COMMENT '管理端累计触发入库次数（含重试/重新入库）' AFTER ingestion_id;
