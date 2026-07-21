DROP PROCEDURE IF EXISTS add_registration_column_if_missing;
DELIMITER $$
CREATE PROCEDURE add_registration_column_if_missing(
    IN column_name_value VARCHAR(64),
    IN column_definition_value TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'sys_user'
          AND column_name = column_name_value
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `sys_user` ADD COLUMN `',
                          column_name_value, '` ', column_definition_value);
        PREPARE statement_handle FROM @ddl;
        EXECUTE statement_handle;
        DEALLOCATE PREPARE statement_handle;
    END IF;
END$$
DELIMITER ;

CALL add_registration_column_if_missing(
    'teacher_certificate_no',
    'VARCHAR(100) NULL COMMENT ''教师资质编号'' AFTER `id_card`'
);
CALL add_registration_column_if_missing(
    'department',
    'VARCHAR(100) NULL COMMENT ''教师所属科室'' AFTER `teacher_certificate_no`'
);

DROP PROCEDURE add_registration_column_if_missing;
