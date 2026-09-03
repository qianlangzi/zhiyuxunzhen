-- ============================================================
-- 为题库 / 病例 / 教材 增加对外统一编号（题号/病例号/教材号），便于管理检索。
-- 编号规则：前缀 + 6 位零填充自增 id（与主键 id 绑定，天然唯一）
--   题库   ST000001   (ST = 试题)
--   病例   BL000001   (BL = 病例)
--   教材   JC000001   (JC = 教材)
-- 存量数据一次性回填；新数据由后端在 create 时按 id 生成，保证不回退。
-- ============================================================

-- ---------- 题库 practice_question ----------
ALTER TABLE practice_question
    ADD COLUMN question_no VARCHAR(32) NULL COMMENT '题库统一题号（如 ST000001）'
        AFTER id;

UPDATE practice_question
SET question_no = CONCAT('ST', LPAD(id, 6, '0'))
WHERE question_no IS NULL OR question_no = '';

-- 防止并发 / 重复写入导致同号，建立唯一索引
ALTER TABLE practice_question
    ADD UNIQUE KEY uk_question_no (question_no);

-- ---------- 病例 sp_case_config ----------
ALTER TABLE sp_case_config
    ADD COLUMN case_no VARCHAR(32) NULL COMMENT '统一病例号（如 BL000001）'
        AFTER id;

UPDATE sp_case_config
SET case_no = CONCAT('BL', LPAD(id, 6, '0'))
WHERE case_no IS NULL OR case_no = '';

ALTER TABLE sp_case_config
    ADD UNIQUE KEY uk_case_no (case_no);

-- ---------- 教材 textbook ----------
ALTER TABLE textbook
    ADD COLUMN textbook_no VARCHAR(32) NULL COMMENT '统一教材号（如 JC000001）'
        AFTER id;

UPDATE textbook
SET textbook_no = CONCAT('JC', LPAD(id, 6, '0'))
WHERE textbook_no IS NULL OR textbook_no = '';

ALTER TABLE textbook
    ADD UNIQUE KEY uk_textbook_no (textbook_no);