-- V8: SP 病例新增「标准答案 / 评分要点」字段（教师自定义，供 AI 评判与广场展示）
DROP PROCEDURE IF EXISTS add_case_reference_column_if_missing;
DELIMITER $$
CREATE PROCEDURE add_case_reference_column_if_missing(
    IN column_name_value VARCHAR(64),
    IN column_definition_value TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'sp_case_config'
          AND column_name = column_name_value
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `sp_case_config` ADD COLUMN `',
                          column_name_value, '` ', column_definition_value);
        PREPARE statement_handle FROM @ddl;
        EXECUTE statement_handle;
        DEALLOCATE PREPARE statement_handle;
    END IF;
END$$
DELIMITER ;

CALL add_case_reference_column_if_missing(
    'reference_answer', 'VARCHAR(4000) NULL COMMENT ''标准答案 / 诊断要点（供 AI 评判与广场展示）'' AFTER `knowledge_tags`'
);
CALL add_case_reference_column_if_missing(
    'scoring_points_json', 'TEXT NULL COMMENT ''评分要点 JSON 数组 [{label,fullMark,criteria,deduct}]'' AFTER `reference_answer`'
);

DROP PROCEDURE add_case_reference_column_if_missing;