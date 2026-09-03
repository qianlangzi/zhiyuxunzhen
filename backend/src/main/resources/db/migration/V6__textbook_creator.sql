-- ============================================================
-- V6: 教材归属（教师上传电子书）
-- 1. textbook 增加 creator_id（上传教师，用于教师端教材管理）
-- ============================================================
ALTER TABLE textbook
    ADD COLUMN creator_id BIGINT NULL COMMENT '上传/创建教材的教师ID' AFTER id;