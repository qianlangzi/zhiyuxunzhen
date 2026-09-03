-- 教材向量化失败原因，供管理端诊断与重试
ALTER TABLE textbook
    ADD COLUMN ingest_error VARCHAR(500) NULL
        COMMENT '最近一次向量化入库失败原因' AFTER ingest_status;
