-- 批阅申诉（学生对大病历/主观题批阅结果有异议时发起，教师处理）
CREATE TABLE IF NOT EXISTS review_appeal (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    review_id BIGINT NOT NULL COMMENT '被申诉的批阅记录ID (medical_record_review.id)',
    instance_id BIGINT NOT NULL COMMENT '作业实例ID (学生发起时冗余，便于教师列表过滤)',
    student_id BIGINT NOT NULL COMMENT '发起申诉的学生',
    reason VARCHAR(1000) NOT NULL COMMENT '申诉理由',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '0待处理 1已处理(已复核/改分) 2已驳回',
    reply VARCHAR(1000) NULL COMMENT '教师处理回复',
    reviewed_by BIGINT NULL COMMENT '处理的教师',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_review (review_id),
    KEY idx_student (student_id, status),
    KEY idx_teacher_status (status, created_at),
    KEY idx_instance (instance_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='批阅申诉';