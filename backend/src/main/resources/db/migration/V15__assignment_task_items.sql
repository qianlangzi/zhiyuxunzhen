-- V15: 组合任务包 - 作业支持 病例问诊(CASE) / 基础练习(PRACTICE) / 阅读任务(READING) 多任务项
-- 兼容策略:存量单病例作业(assignment 无对应 assignment_item 行)完全走旧逻辑,字段保留可空。

-- 1. assignment.case_id 改可空(组合包作业 case 挂在任务项上)
ALTER TABLE assignment MODIFY COLUMN case_id BIGINT NULL COMMENT '兼容存量:单病例作业的病例ID(组合包作业为NULL)';

-- 2. assignment_instance.case_id 改可空,新增总分
ALTER TABLE assignment_instance MODIFY COLUMN case_id BIGINT NULL COMMENT '兼容存量:存量作业的病例ID(组合包作业为NULL)';
ALTER TABLE assignment_instance ADD COLUMN score DECIMAL(5,2) NULL COMMENT '作业总分(组合包聚合)' AFTER submit_time;

-- 3. chat_session 新增任务项进度挂载点(组合包:病例任务项问诊会话;存量作业为NULL)
ALTER TABLE chat_session ADD COLUMN assignment_item_progress_id BIGINT NULL COMMENT '组合包:病例任务项进度ID(存量为NULL)' AFTER assignment_instance_id;
ALTER TABLE chat_session ADD KEY idx_item_progress (assignment_item_progress_id);

-- 3.1 medical_record_review 新增任务项进度挂载点(组合包:病例任务项批阅记录)
ALTER TABLE medical_record_review ADD COLUMN assignment_item_progress_id BIGINT NULL COMMENT '组合包:病例任务项进度ID(存量为NULL,按instance_id)' AFTER instance_id;
ALTER TABLE medical_record_review ADD KEY idx_item_progress (assignment_item_progress_id);

-- 4. 作业任务项表
CREATE TABLE IF NOT EXISTS assignment_item (
    id                       BIGINT       NOT NULL AUTO_INCREMENT,
    assignment_id            BIGINT       NOT NULL,
    item_type                VARCHAR(20)  NOT NULL COMMENT 'CASE病例问诊 / PRACTICE基础练习 / READING阅读任务',
    title                    VARCHAR(200) NOT NULL,
    sort_order               INT          NOT NULL DEFAULT 0,
    case_id                  BIGINT       NULL COMMENT 'CASE:病例ID',
    anti_cheat_variables     JSON         NULL COMMENT 'CASE:防作弊变量模板',
    require_medical_record   TINYINT(1)   NOT NULL DEFAULT 1 COMMENT 'CASE:是否要求提交大病历',
    format_rule_json         JSON         NULL COMMENT 'CASE:格式盾牌规则',
    question_ids             JSON         NULL COMMENT 'PRACTICE:题目ID列表 [1,2,3]',
    textbook_id              BIGINT       NULL COMMENT 'READING:教材ID',
    reading_scope            VARCHAR(500) NULL COMMENT 'READING:阅读范围(章节/页码范围)',
    is_deleted               TINYINT      NOT NULL DEFAULT 0,
    created_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_assignment (assignment_id),
    KEY idx_item_case (case_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='作业任务项表(组合任务包)';

-- 5. 学生作业任务项进度表
CREATE TABLE IF NOT EXISTS assignment_item_progress (
    id                       BIGINT       NOT NULL AUTO_INCREMENT,
    instance_id              BIGINT       NOT NULL,
    item_id                  BIGINT       NOT NULL,
    student_id               BIGINT       NOT NULL,
    case_id                  BIGINT       NULL COMMENT 'CASE:病例ID',
    variable_snapshot_json   JSON         NULL COMMENT 'CASE:防作弊变量快照',
    session_id               BIGINT       NULL COMMENT 'CASE:问诊会话ID',
    medical_record_text      LONGTEXT     NULL COMMENT 'CASE:大病历正文',
    format_check_result      JSON         NULL COMMENT 'CASE:格式盾牌校验结果',
    answers_json             JSON         NULL COMMENT 'PRACTICE:学生答案 {"qid":{"answer":"...","correct":true}}',
    score                    DECIMAL(5,2) NULL COMMENT '得分(练习自动判分/病例AI评分/教师复核)',
    completed_at             DATETIME     NULL COMMENT '完成时间(阅读标记/练习交卷)',
    submit_time              DATETIME     NULL,
    ai_error_message         VARCHAR(500) NULL,
    ai_retry_count           INT          NOT NULL DEFAULT 0,
    ai_last_attempt_at       DATETIME     NULL,
    status                   TINYINT      NOT NULL DEFAULT 0 COMMENT '0未开始 1进行中 2已提交/格式打回 3AI批阅中 4待复核 5已完成',
    is_deleted               TINYINT      NOT NULL DEFAULT 0,
    created_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_instance_item (instance_id, item_id),
    KEY idx_item (item_id),
    KEY idx_student (student_id),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生作业任务项进度表(组合任务包)';
