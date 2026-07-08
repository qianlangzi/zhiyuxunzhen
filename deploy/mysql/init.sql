-- ============================================================
-- 智愈寻真 数据库初始化脚本（PRD 第八章 12 张表）
-- 字符集 utf8mb4 / 引擎 InnoDB
-- ============================================================

CREATE DATABASE IF NOT EXISTS zhiyu_db
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE zhiyu_db;

-- ---------- 1. sys_user 系统用户表（PRD 8.1） ----------
CREATE TABLE IF NOT EXISTS sys_user (
    id                  BIGINT       NOT NULL AUTO_INCREMENT,
    username            VARCHAR(50)  NOT NULL,
    password_hash       VARCHAR(255) NOT NULL,
    real_name           VARCHAR(50),
    role                TINYINT      NOT NULL DEFAULT 0  COMMENT '0学生 1教师 2教学秘书 3教研室主任 4管理员 5运维',
    class_id            BIGINT                            COMMENT '学生所属班级',
    audit_status        TINYINT      NOT NULL DEFAULT 0  COMMENT '教师认证:0未提交 1待审 2通过 3驳回',
    status              TINYINT      NOT NULL DEFAULT 0  COMMENT '0正常 1冻结',
    phone               VARCHAR(20),
    id_card             VARCHAR(32),
    avatar              VARCHAR(255),
    authorized_classes  JSON                              COMMENT '教师授权班级ID数组',
    last_login_at       DATETIME,
    is_deleted          TINYINT      NOT NULL DEFAULT 0,
    created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_username (username),
    KEY idx_role (role),
    KEY idx_class (class_id),
    KEY idx_audit (audit_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统用户表';

-- ---------- 2. sp_case_config 病例配置表（PRD 8.2） ----------
CREATE TABLE IF NOT EXISTS sp_case_config (
    id                  BIGINT        NOT NULL AUTO_INCREMENT,
    creator_id          BIGINT        NOT NULL,
    source_case_id      BIGINT                             COMMENT '引用来源病例ID,自建为空',
    title               VARCHAR(100)  NOT NULL,
    department          VARCHAR(50),
    difficulty          TINYINT       NOT NULL DEFAULT 2  COMMENT '1简单 2标准 3困难',
    patient_profile     JSON,
    hidden_disease      VARCHAR(100),
    standard_path_json  JSON,
    preset_exams        JSON,
    knowledge_tags      JSON,
    is_public           TINYINT(1)    NOT NULL DEFAULT 0,
    reference_count     INT           NOT NULL DEFAULT 0,
    rating_avg          DECIMAL(2,1)  NOT NULL DEFAULT 0.0,
    admin_audit_status  TINYINT       NOT NULL DEFAULT 0  COMMENT '0未提交 1待审 2通过 3驳回 4下架',
    version             INT           NOT NULL DEFAULT 1,
    status              TINYINT       NOT NULL DEFAULT 0  COMMENT '0草稿 1已发布',
    is_deleted          TINYINT       NOT NULL DEFAULT 0,
    created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_creator (creator_id),
    KEY idx_public (is_public, admin_audit_status),
    KEY idx_department (department)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='病例配置表';

-- ---------- 3. assignment 作业表（PRD 8.3） ----------
CREATE TABLE IF NOT EXISTS assignment (
    id                       BIGINT       NOT NULL AUTO_INCREMENT,
    teacher_id               BIGINT       NOT NULL,
    case_id                  BIGINT       NOT NULL,
    title                    VARCHAR(200) NOT NULL,
    description              TEXT,
    require_medical_record   TINYINT(1)   NOT NULL DEFAULT 0,
    format_rule_json         JSON,
    anti_cheat_variables     JSON,
    deadline                 DATETIME,
    allow_late_submit        TINYINT(1)   NOT NULL DEFAULT 0,
    status                   TINYINT      NOT NULL DEFAULT 0  COMMENT '0草稿 1进行中 2已截止',
    is_deleted               TINYINT      NOT NULL DEFAULT 0,
    created_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_teacher (teacher_id),
    KEY idx_case (case_id),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='作业表';

-- ---------- 4. assignment_instance 学生作业实例表（PRD 8.4） ----------
CREATE TABLE IF NOT EXISTS assignment_instance (
    id                       BIGINT   NOT NULL AUTO_INCREMENT,
    assignment_id            BIGINT   NOT NULL,
    student_id               BIGINT   NOT NULL,
    case_id                  BIGINT   NOT NULL,
    variable_snapshot_json   JSON,
    session_id               BIGINT,
    medical_record_text      LONGTEXT,
    format_check_result      JSON,
    submit_time              DATETIME,
    status                   TINYINT  NOT NULL DEFAULT 0  COMMENT '0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成',
    is_deleted               TINYINT  NOT NULL DEFAULT 0,
    created_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_assign_student (assignment_id, student_id),
    KEY idx_student (student_id),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生作业实例表';

-- ---------- 5. medical_record_review 批阅记录表（PRD 8.5） ----------
CREATE TABLE IF NOT EXISTS medical_record_review (
    id                      BIGINT        NOT NULL AUTO_INCREMENT,
    instance_id             BIGINT        NOT NULL,
    reviewer_type           VARCHAR(20)   NOT NULL  COMMENT 'AI / TEACHER',
    total_score             DECIMAL(5,2),
    mistakes_json           JSON,
    review_comment          TEXT,
    override_from_review_id BIGINT,
    reviewed_by             BIGINT,
    created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_instance (instance_id),
    KEY idx_reviewer (reviewer_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='批阅记录表';

-- ---------- 6. chat_session 问诊会话表（PRD 8.6） ----------
CREATE TABLE IF NOT EXISTS chat_session (
    id                       BIGINT        NOT NULL AUTO_INCREMENT,
    student_id               BIGINT        NOT NULL,
    case_id                  BIGINT        NOT NULL,
    assignment_instance_id   BIGINT,
    osce_score_json          JSON,
    final_report             TEXT,
    reasoning_tree_json      JSON,
    total_exam_cost          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status                   TINYINT       NOT NULL DEFAULT 0  COMMENT '0进行中 1已完成 2异常中断',
    created_at               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    ended_at                 DATETIME,
    PRIMARY KEY (id),
    KEY idx_student (student_id),
    KEY idx_case (case_id),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='问诊会话表';

-- ---------- 7. chat_message_log 对话明细表（PRD 8.7） ----------
CREATE TABLE IF NOT EXISTS chat_message_log (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    session_id      BIGINT       NOT NULL,
    sender          VARCHAR(20)  NOT NULL  COMMENT 'STUDENT / SP / MENTOR / SYSTEM',
    content         TEXT,
    multimodal_url  VARCHAR(255),
    annotation_json JSON,
    citations       JSON,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_session (session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='对话明细表';

-- ---------- 8. student_mistakes 学生错题本表（PRD 8.8） ----------
CREATE TABLE IF NOT EXISTS student_mistakes (
    id               BIGINT      NOT NULL AUTO_INCREMENT,
    student_id       BIGINT      NOT NULL,
    session_id       BIGINT,
    case_id          BIGINT,
    mistake_type     VARCHAR(50) NOT NULL  COMMENT 'diagnosis/history/exam/record/communication',
    knowledge_tag    VARCHAR(100),
    student_answer   TEXT,
    standard_answer  TEXT,
    evidence_json    JSON,
    resolved_status  TINYINT     NOT NULL DEFAULT 0  COMMENT '0未复习 1已复习 2已掌握',
    created_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_student (student_id),
    KEY idx_type (mistake_type),
    KEY idx_resolved (resolved_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生错题本表';

-- ---------- 9. student_weakness 薄弱知识点表（PRD 8.9） ----------
CREATE TABLE IF NOT EXISTS student_weakness (
    id                     BIGINT        NOT NULL AUTO_INCREMENT,
    student_id             BIGINT        NOT NULL,
    knowledge_tag          VARCHAR(100)  NOT NULL,
    weakness_score         DECIMAL(3,2)  NOT NULL DEFAULT 1.00  COMMENT '掌握度 0.00~1.00',
    evidence_count         INT           NOT NULL DEFAULT 0,
    recommended_path_json  JSON,
    last_updated           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_student_tag (student_id, knowledge_tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='薄弱知识点表';

-- ---------- 10. daily_case_schedule 每日一例排期表（PRD 8.10） ----------
CREATE TABLE IF NOT EXISTS daily_case_schedule (
    id            BIGINT      NOT NULL AUTO_INCREMENT,
    case_id       BIGINT      NOT NULL,
    publish_date  DATE        NOT NULL,
    target_grade  VARCHAR(20),
    status        TINYINT     NOT NULL DEFAULT 0  COMMENT '0草稿 1已排期 2已发布',
    created_by    BIGINT,
    created_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_date (publish_date),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日一例排期表';

-- ---------- 11. sys_config 系统配置表（PRD 8.11） ----------
CREATE TABLE IF NOT EXISTS sys_config (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    config_key    VARCHAR(100) NOT NULL,
    config_value  TEXT,
    config_type   VARCHAR(50)  COMMENT 'MODEL/SAFETY/DAILY_CASE/TOKEN_BUDGET',
    updated_by    BIGINT,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统配置表';

-- ---------- 12. audit_log 审计日志表（PRD 8.12） ----------
CREATE TABLE IF NOT EXISTS audit_log (
    id             BIGINT       NOT NULL AUTO_INCREMENT,
    operator_id    BIGINT,
    operator_role  TINYINT,
    action         VARCHAR(100) NOT NULL,
    target_type    VARCHAR(50),
    target_id      BIGINT,
    before_json    JSON,
    after_json     JSON,
    ip_address     VARCHAR(64),
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_operator (operator_id),
    KEY idx_action (action),
    KEY idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='审计日志表';
