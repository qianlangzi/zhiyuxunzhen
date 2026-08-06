-- 注册资料扩展：学生学校/年级/班级、教师教资证书图片
-- 兼容已有数据库：仅在列不存在时新增

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
    'school_name',
    'VARCHAR(100) NULL COMMENT ''学校名称'' AFTER `department`'
);
CALL add_registration_column_if_missing(
    'grade',
    'VARCHAR(20) NULL COMMENT ''学生年级'' AFTER `school_name`'
);
CALL add_registration_column_if_missing(
    'class_name',
    'VARCHAR(50) NULL COMMENT ''学生班级名称'' AFTER `grade`'
);
CALL add_registration_column_if_missing(
    'teacher_certificate_image',
    'VARCHAR(255) NULL COMMENT ''教师资质证书图片路径'' AFTER `class_name`'
);

DROP PROCEDURE add_registration_column_if_missing;
