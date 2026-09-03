-- ============================================================
-- V10: 基础题库审核闭环 + 教材向量化入库状态
-- ------------------------------------------------------------
-- 1) practice_question 增加审核状态（沿用病例 admin_audit_status 语义）
--    0未提交审核 1待审核(管理端) 2审核通过(学生可见) 3审核驳回
--    现有存量题目视为已通过（2），保证学生端原有题库可用。
-- 2) textbook 增加向量化入库状态，供管理端"入向量数据库"管理：
--    0未入库 1处理中 2已入库 3入库失败
-- ============================================================

ALTER TABLE practice_question
    ADD COLUMN admin_audit_status TINYINT NOT NULL DEFAULT 0
        COMMENT '题库审核状态:0未提交 1待审核 2通过 3驳回' AFTER source_textbook_id,
    ADD COLUMN submitter_id BIGINT NULL
        COMMENT '提交人(教师)ID' AFTER admin_audit_status,
    ADD COLUMN reject_reason VARCHAR(500) NULL
        COMMENT '管理端驳回复核意见' AFTER submitter_id,
    ADD INDEX idx_question_audit (admin_audit_status, submitter_id);

-- 存量题目默认视为已审核通过，保证学生端已可见的题不消失
UPDATE practice_question SET admin_audit_status = 2 WHERE is_deleted = 0;

ALTER TABLE textbook
    ADD COLUMN ingest_status TINYINT NOT NULL DEFAULT 0
        COMMENT '向量化入库状态:0未入库 1处理中 2已入库 3失败' AFTER status,
    ADD COLUMN last_ingest_at DATETIME NULL
        COMMENT '最近一次触发向量化入库时间' AFTER ingest_status;