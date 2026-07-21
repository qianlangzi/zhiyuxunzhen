-- Flutter Mobile 全链路联调的增量结构。
-- 本迁移同时兼容已有 12 表数据库与由 deploy/mysql/init.sql 创建的新数据库。

DROP PROCEDURE IF EXISTS add_column_if_missing;
DELIMITER $$
CREATE PROCEDURE add_column_if_missing(
    IN table_name_value VARCHAR(64),
    IN column_name_value VARCHAR(64),
    IN column_definition_value TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = table_name_value
          AND column_name = column_name_value
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', table_name_value, '` ADD COLUMN `',
                          column_name_value, '` ', column_definition_value);
        PREPARE statement_handle FROM @ddl;
        EXECUTE statement_handle;
        DEALLOCATE PREPARE statement_handle;
    END IF;
END$$
DELIMITER ;

CALL add_column_if_missing('assignment_instance', 'ai_error_message', 'VARCHAR(500) NULL AFTER `submit_time`');
CALL add_column_if_missing('assignment_instance', 'ai_retry_count', 'INT NOT NULL DEFAULT 0 AFTER `ai_error_message`');
CALL add_column_if_missing('assignment_instance', 'ai_last_attempt_at', 'DATETIME NULL AFTER `ai_retry_count`');
CALL add_column_if_missing('daily_case_schedule', 'question', 'TEXT NULL AFTER `target_grade`');
CALL add_column_if_missing('daily_case_schedule', 'options_json', 'JSON NULL AFTER `question`');
CALL add_column_if_missing('daily_case_schedule', 'standard_answer', 'VARCHAR(255) NULL AFTER `options_json`');
CALL add_column_if_missing('daily_case_schedule', 'answer_explanation', 'TEXT NULL AFTER `standard_answer`');
CALL add_column_if_missing('daily_case_schedule', 'textbook_ref', 'VARCHAR(255) NULL AFTER `answer_explanation`');

DROP PROCEDURE add_column_if_missing;

DROP PROCEDURE IF EXISTS add_index_if_missing;
DELIMITER $$
CREATE PROCEDURE add_index_if_missing(
    IN table_name_value VARCHAR(64),
    IN index_name_value VARCHAR(64),
    IN index_definition_value TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = table_name_value
          AND index_name = index_name_value
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', table_name_value, '` ADD ', index_definition_value);
        PREPARE statement_handle FROM @ddl;
        EXECUTE statement_handle;
        DEALLOCATE PREPARE statement_handle;
    END IF;
END$$
DELIMITER ;

CALL add_index_if_missing('sys_user', 'uk_phone', 'UNIQUE KEY `uk_phone` (`phone`)');
DROP PROCEDURE add_index_if_missing;

CREATE TABLE IF NOT EXISTS teaching_class (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    grade       VARCHAR(20),
    status      TINYINT      NOT NULL DEFAULT 0 COMMENT '0正常 1停用',
    is_deleted  TINYINT      NOT NULL DEFAULT 0,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_class_name_grade (name, grade),
    KEY idx_class_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='教学班级表';

CREATE TABLE IF NOT EXISTS teacher_class_authorization (
    id          BIGINT   NOT NULL AUTO_INCREMENT,
    teacher_id  BIGINT   NOT NULL,
    class_id    BIGINT   NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_teacher_class (teacher_id, class_id),
    KEY idx_authorized_class (class_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='教师班级授权表';

CREATE TABLE IF NOT EXISTS assignment_target_class (
    id            BIGINT   NOT NULL AUTO_INCREMENT,
    assignment_id BIGINT   NOT NULL,
    class_id      BIGINT   NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_assignment_class (assignment_id, class_id),
    KEY idx_target_class (class_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='作业目标班级表';

CREATE TABLE IF NOT EXISTS daily_case_submission (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    schedule_id     BIGINT       NOT NULL,
    student_id      BIGINT       NOT NULL,
    answer          VARCHAR(255) NOT NULL,
    is_correct      TINYINT(1),
    evaluation_json JSON,
    submitted_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_daily_student (schedule_id, student_id),
    KEY idx_daily_student (student_id),
    KEY idx_daily_submitted (submitted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日一例提交表';
