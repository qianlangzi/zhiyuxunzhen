-- ============================================================
-- V11: 智能备课（助教核心）+ 学情预警 + 站内信通知
-- ------------------------------------------------------------
-- 1) lesson_plan          备课包（教学设计 + 关联病例 + 资料 + 发布）
-- 2) lesson_material      备课资料（PDF/PPT/MP4/MP3/图片，可独立发放）
-- 3) lesson_publish       备课发布记录（关联 assignment；material_only 表示仅发资料）
-- 4) student_alert        学情预警记录（Rule-first 规则引擎扫描结果）
-- 5) sys_notification     站内信（预警推送/作业提醒等）
-- 6) practice_question    扩展主观题类型（essay）+ 评分要点
-- 7) assignment           扩展组卷（question_ids_json，主观题作业）
-- ============================================================

-- 1. 备课包
CREATE TABLE IF NOT EXISTS lesson_plan (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    teacher_id       BIGINT       NOT NULL COMMENT '创建教师ID',
    title            VARCHAR(200) NOT NULL COMMENT '备课标题',
    department       VARCHAR(50)  NULL COMMENT '科室/疾病系统',
    target_grade     VARCHAR(20)  NULL COMMENT '适用年级',
    objectives_json  JSON         NULL COMMENT '教学目标（可AI生成）',
    key_points_json  JSON         NULL COMMENT '教学重难点',
    ai_design_json   JSON         NULL COMMENT 'AI教学设计（教案大纲/课堂活动/讨论题）',
    case_id          BIGINT       NULL COMMENT '关联SP病例ID（自建或引用）',
    case_source      TINYINT      NOT NULL DEFAULT 0 COMMENT '病例来源:0无 1自建 2引用病例广场',
    status           TINYINT      NOT NULL DEFAULT 0 COMMENT '0草稿 1已发布',
    is_deleted       TINYINT      NOT NULL DEFAULT 0,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_lesson_teacher (teacher_id),
    KEY idx_lesson_case (case_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='智能备课包';

-- 2. 备课资料（课件资料库）
CREATE TABLE IF NOT EXISTS lesson_material (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    lesson_id        BIGINT       NOT NULL COMMENT '所属备课包',
    material_type    VARCHAR(10)  NOT NULL COMMENT 'pdf/ppt/mp4/mp3/image',
    title            VARCHAR(200) NOT NULL COMMENT '资料标题',
    file_url         VARCHAR(500) NULL COMMENT '文件访问地址',
    object_key       VARCHAR(255) NULL COMMENT '对象存储key',
    knowledge_tags   JSON         NULL COMMENT '知识点标签',
    ocr_text         LONGTEXT     NULL COMMENT 'PDF/PPT提取文本（入知识库用）',
    duration_sec     INT          NULL COMMENT '音视频时长（秒）',
    is_deleted       TINYINT      NOT NULL DEFAULT 0,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_mat_lesson (lesson_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='备课资料';

-- 3. 备课发布记录（material_only=1 表示资料独立发放，不绑定作业）
CREATE TABLE IF NOT EXISTS lesson_publish (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    lesson_id        BIGINT       NOT NULL COMMENT '备课包',
    assignment_id    BIGINT       NULL COMMENT '关联作业ID（material_only=0时）',
    class_id         BIGINT       NOT NULL COMMENT '发布班级',
    material_only    TINYINT      NOT NULL DEFAULT 0 COMMENT '1仅发资料 0资料+病例+作业',
    deadline         DATETIME     NULL COMMENT '截止时间',
    status           TINYINT      NOT NULL DEFAULT 0 COMMENT '0已发布 1已结束',
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_pub_lesson (lesson_id),
    KEY idx_pub_class (class_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='备课发布记录';

-- 4. 学情预警记录
CREATE TABLE IF NOT EXISTS student_alert (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id       BIGINT       NOT NULL COMMENT '学生ID',
    class_id         BIGINT       NULL COMMENT '班级ID',
    alert_type       VARCHAR(30)  NOT NULL COMMENT 'osce_low/assignment_overdue/daily_break/weakness_worsening/behavior_abnormal',
    risk_level       TINYINT      NOT NULL DEFAULT 2 COMMENT '1低 2中 3高',
    rule_detail_json JSON         NULL COMMENT '触发规则明细（连续次数/数值等）',
    status           TINYINT      NOT NULL DEFAULT 0 COMMENT '0未处理 1已查看 2已干预',
    intervention_json JSON       NULL COMMENT 'AI干预建议（缓存）',
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at      DATETIME     NULL,
    KEY idx_alert_student (student_id),
    KEY idx_alert_class (class_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='学情预警';

-- 5. 站内信通知
CREATE TABLE IF NOT EXISTS sys_notification (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    recipient_id     BIGINT       NOT NULL COMMENT '接收人ID（教师）',
    notify_type      VARCHAR(30)  NOT NULL COMMENT 'alert/assignment/review/system',
    title            VARCHAR(200) NOT NULL COMMENT '通知标题',
    content          VARCHAR(1000) NULL COMMENT '通知内容',
    ref_id           BIGINT       NULL COMMENT '关联对象ID（如预警ID/作业ID）',
    is_read          TINYINT      NOT NULL DEFAULT 0 COMMENT '0未读 1已读',
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_notify_recipient (recipient_id, is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='站内信';

-- 6. 主观题扩展：practice_question 加评分要点（question_type 列已存在：single_choice/multiple_choice/judgment/fill_blank，主观题用 essay）
ALTER TABLE practice_question
    ADD COLUMN scoring_points_json JSON NULL
        COMMENT '主观题评分要点（教师自定义）' AFTER answer;

-- 7. 作业组卷扩展：assignment 加题目组（主观题作业）
ALTER TABLE assignment
    ADD COLUMN question_ids_json JSON NULL
        COMMENT '作业题目组卷ID列表（question_ids），与case_id二选一' AFTER case_id,
    ADD COLUMN assignment_type TINYINT NOT NULL DEFAULT 0
        COMMENT '0病例作业 1组卷作业(题目)' AFTER question_ids_json;
