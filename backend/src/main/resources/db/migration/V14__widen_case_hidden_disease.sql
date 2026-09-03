-- V14: 放宽 SP 病例长文本列，承载 AI 生成的内容
-- AI 草稿自动填充后保存时：
--  - hidden_disease 原 VARCHAR(100) 过短，触发 "Data too long" 500，教师端保存/发布失败；
--  - reference_answer 原 VARCHAR(4000)，AI 生成的长鉴别诊断偶尔也会超限。
-- 其余 AI 填充字段（patient_profile / standard_path_json / preset_exams /
-- knowledge_tags 为 JSON，scoring_points_json TEXT）容量已足够。
DROP PROCEDURE IF EXISTS widen_case_text_columns;
DELIMITER $$
CREATE PROCEDURE widen_case_text_columns()
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'sp_case_config'
          AND column_name = 'hidden_disease'
          AND data_type = 'varchar'
    ) THEN
        ALTER TABLE `sp_case_config`
            MODIFY `hidden_disease` TEXT NULL COMMENT '隐藏疾病 / 真实诊断（可含 AI 生成长文本）';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'sp_case_config'
          AND column_name = 'reference_answer'
          AND data_type = 'varchar'
    ) THEN
        ALTER TABLE `sp_case_config`
            MODIFY `reference_answer` TEXT NULL COMMENT '标准答案 / 诊断要点（可含 AI 生成长文本）';
    END IF;
END$$
DELIMITER ;
CALL widen_case_text_columns();
DROP PROCEDURE widen_case_text_columns;