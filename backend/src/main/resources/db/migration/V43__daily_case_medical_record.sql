-- ============================================================
-- V43: 每日一例 → 每日病历（LeetCode 式训练闭环）
-- ------------------------------------------------------------
-- 背景：每日一例原为"开放作答一段诊断+依据"，学生写完只拿一个
-- correct 布尔值，无过程引导、无缺陷定位、无沉淀。
-- 本迁移把它升级为「每日病历」：九段结构化书写 + AI 段落教练 +
-- 结构化批阅 + 缺陷打标沉淀 + 题库/打卡。
--
-- 设计原则（与历史迁移一致）：
--   1. 全部增量，禁止 DROP / DELETE 用户数据
--   2. 加列用 information_schema 判存在的存储过程，保证幂等可重放
--   3. 新表用 CREATE TABLE IF NOT EXISTS
-- ============================================================

-- ---------- 1. 排期表扩展：难度/系统/病例摘要/参考病历/书写模式 ----------
DROP PROCEDURE IF EXISTS add_daily_case_mr_columns;
DELIMITER $$
CREATE PROCEDURE add_daily_case_mr_columns()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'daily_case_schedule'
          AND column_name = 'case_summary'
    ) THEN
        ALTER TABLE `daily_case_schedule`
            ADD COLUMN `case_summary` LONGTEXT COMMENT '病例摘要：患者画像+关键检查，供书写与AI批阅参考' AFTER `question`;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'daily_case_schedule'
          AND column_name = 'difficulty'
    ) THEN
        ALTER TABLE `daily_case_schedule`
            ADD COLUMN `difficulty` TINYINT NOT NULL DEFAULT 2 COMMENT '难度：1入门 2进阶 3挑战' AFTER `case_summary`;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'daily_case_schedule'
          AND column_name = 'system_tag'
    ) THEN
        ALTER TABLE `daily_case_schedule`
            ADD COLUMN `system_tag` VARCHAR(32) DEFAULT NULL COMMENT '系统/科室标签，如 呼吸/循环/消化' AFTER `difficulty`;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'daily_case_schedule'
          AND column_name = 'writing_mode'
    ) THEN
        ALTER TABLE `daily_case_schedule`
            ADD COLUMN `writing_mode` TINYINT NOT NULL DEFAULT 1 COMMENT '作答模式：0开放作答(旧) 1大病历九段书写' AFTER `system_tag`;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'daily_case_schedule'
          AND column_name = 'reference_record'
    ) THEN
        ALTER TABLE `daily_case_schedule`
            ADD COLUMN `reference_record` LONGTEXT COMMENT '参考病历（教师/教研提供），学生提交后可见' AFTER `answer_explanation`;
    END IF;
END$$
DELIMITER ;
CALL add_daily_case_mr_columns();
DROP PROCEDURE add_daily_case_mr_columns;

-- ---------- 2. 病历记录表（支持多次提交/版本迭代） ----------
CREATE TABLE IF NOT EXISTS `daily_case_record` (
    `id`             BIGINT   NOT NULL AUTO_INCREMENT,
    `schedule_id`    BIGINT   NOT NULL COMMENT '每日一例排期ID',
    `student_id`     BIGINT   NOT NULL,
    `version`        INT      NOT NULL DEFAULT 1 COMMENT '第几次提交（同一排期可反复修订）',
    `status`         TINYINT  NOT NULL DEFAULT 0 COMMENT '0草稿 1已提交待批 2已批阅',
    `total_score`    DECIMAL(5,2) DEFAULT NULL COMMENT 'AI批阅总分（百分制）',
    `ai_confidence`  DECIMAL(3,2) DEFAULT NULL COMMENT 'AI批阅置信度0-1，>=0.85教师端可免复核',
    `content_json`   LONGTEXT COMMENT '九段内容 JSON: {"chief_complaint":"...",...}',
    `review_json`    LONGTEXT COMMENT 'AI批阅结果 JSON（九段分+缺陷清单+评语）',
    `teacher_score`  DECIMAL(5,2) DEFAULT NULL COMMENT '教师复核后的最终分（覆盖AI分）',
    `teacher_comment` VARCHAR(500) DEFAULT NULL COMMENT '教师复核评语',
    `reviewed_by`    BIGINT   DEFAULT NULL COMMENT '复核教师ID',
    `submitted_at`   DATETIME DEFAULT NULL,
    `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_record_version` (`schedule_id`, `student_id`, `version`),
    KEY `idx_record_student` (`student_id`),
    KEY `idx_record_schedule` (`schedule_id`),
    KEY `idx_record_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日病历记录表（支持版本迭代）';

-- ---------- 3. 病历段落表（逐段存储，支撑逐段批阅） ----------
CREATE TABLE IF NOT EXISTS `daily_case_segment` (
    `id`            BIGINT   NOT NULL AUTO_INCREMENT,
    `record_id`     BIGINT   NOT NULL,
    `segment_key`   VARCHAR(40)  NOT NULL COMMENT '段落key，如 chief_complaint',
    `segment_order` INT      NOT NULL COMMENT '段序1-9',
    `content`       LONGTEXT COMMENT '学生书写内容',
    `score`         DECIMAL(5,2) DEFAULT NULL COMMENT '该段得分',
    `full_score`    DECIMAL(5,2) DEFAULT NULL COMMENT '该段满分',
    `feedback_json` LONGTEXT COMMENT '段落级反馈 JSON（缺陷+建议）',
    `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_segment` (`record_id`, `segment_key`),
    KEY `idx_segment_record` (`record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='每日病历段落表（九段）';

-- ---------- 4. 缺陷标签字典 ----------
CREATE TABLE IF NOT EXISTS `mr_defect_tag` (
    `id`         BIGINT      NOT NULL AUTO_INCREMENT,
    `code`       VARCHAR(40) NOT NULL COMMENT '缺陷代码，如 CC_TOO_LONG',
    `name`       VARCHAR(80) NOT NULL COMMENT '缺陷名称',
    `segment_key` VARCHAR(40) DEFAULT NULL COMMENT '所属段落key，NULL=通用',
    `category`   VARCHAR(20) NOT NULL DEFAULT '规范' COMMENT '规范/缺项/逻辑/思维',
    `level`      TINYINT     NOT NULL DEFAULT 1 COMMENT '1轻微 2一般 3严重',
    `advice`     VARCHAR(300) DEFAULT NULL COMMENT '改进建议模板',
    `sort`       INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_defect_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='病历缺陷标签字典';

INSERT IGNORE INTO `mr_defect_tag` (`code`, `name`, `segment_key`, `category`, `level`, `advice`, `sort`) VALUES
('CC_TOO_LONG',      '主诉超过20字',        'chief_complaint', '规范', 2, '主诉应精炼，建议压缩为「症状+时限」', 10),
('CC_HAS_DIAGNOSIS', '主诉含诊断性词语',    'chief_complaint', '规范', 2, '主诉只写症状与时限，不写诊断结论', 11),
('CC_NO_DURATION',   '主诉缺时限',          'chief_complaint', '缺项', 3, '主诉必须包含症状持续时间', 12),
('HPI_NO_ONSET',     '现病史缺起病情况',    'history_present', '缺项', 3, '补充起病时间、缓急、诱因', 20),
('HPI_NO_COURSE',    '现病史缺病情演变',    'history_present', '缺项', 2, '描述症状如何变化、加重或缓解', 21),
('HPI_NO_CAUSE',     '现病史缺诱因',        'history_present', '缺项', 1, '补充可能的诱因（受凉、劳累、饮食等）', 22),
('HPI_NO_RELIEF',    '缺缓解/加重因素',     'history_present', '缺项', 2, '说明什么情况下症状缓解或加重', 23),
('HPI_NO_GENERAL',   '缺一般情况',          'history_present', '缺项', 1, '补充精神、食欲、睡眠、体重变化', 24),
('HPI_TIMELINE_CHAOS','现病史时序混乱',      'history_present', '逻辑', 3, '按时间顺序重新组织病情经过', 25),
('PMH_MISSING',      '既往史缺失',          'history_past',    '缺项', 2, '补充既往疾病、手术、外伤、过敏史', 30),
('PMH_NO_FILTER',    '既往史未筛选相关性',  'history_past',    '思维', 1, '只保留与本次疾病相关的既往史', 31),
('PE_NO_VITALS',     '查体缺生命体征',      'physical_exam',   '缺项', 3, '首行记录 T/P/R/BP', 40),
('PE_NO_POSITIVE',   '缺阳性体征',          'physical_exam',   '缺项', 3, '记录本次查体发现的异常体征', 41),
('PE_NO_NEGATIVE',   '缺鉴别意义的阴性体征','physical_exam',   '缺项', 2, '记录用于排除其他诊断的阴性体征', 42),
('PE_DISORDER',      '查体顺序混乱',        'physical_exam',   '规范', 2, '按一般→头颈→胸→腹→脊柱四肢→神经顺序书写', 43),
('AE_MISSING',       '辅助检查缺失',        'auxiliary_exam',  '缺项', 2, '列出已做的检查及结果', 50),
('AE_IRRATIONAL',    '检查选择不合理',      'auxiliary_exam',  '思维', 2, '检查应针对诊断假设，避免无目的开单', 51),
('DX_INCOMPLETE',    '初步诊断不完整',      'diagnosis',       '缺项', 2, '诊断尽量包含病因/部位/分期/分型', 60),
('DX_ORDER',         '诊断主次顺序不当',    'diagnosis',       '规范', 1, '主要诊断在前，并发症/伴发病在后', 61),
('BASIS_INSUFFICIENT','诊断依据不充分',     'diagnosis_basis', '思维', 3, '逐条列出支持诊断的症状、体征、检查结果', 70),
('BASIS_NO_QUOTE',   '依据未引用病历内容',  'diagnosis_basis', '逻辑', 2, '依据应引用病历中已有的具体发现', 71),
('DDX_INSUFFICIENT', '鉴别诊断不足2个',     'differential',    '缺项', 3, '至少列出2个需鉴别的疾病', 80),
('DDX_NO_SUPPORT',   '鉴别无支持点',        'differential',    '思维', 2, '说明该病为何需要考虑', 81),
('DDX_NO_EXCLUDE',   '鉴别无排除点',        'differential',    '思维', 2, '说明依据什么排除该病', 82),
('PLAN_GENERIC',     '诊疗计划泛化',        'treatment_plan',  '思维', 2, '计划应针对本患者具体情况，避免套话', 90),
('PLAN_NO_FOLLOWUP', '诊疗计划缺随访',      'treatment_plan',  '缺项', 1, '补充随访安排与观察指标', 91),
('TERM_ERROR',       '医学术语使用错误',    NULL,              '规范', 2, '核对教材规范术语', 100),
('LOGIC_CONFLICT',   '内容前后矛盾',        NULL,              '逻辑', 3, '检查各段落之间是否存在矛盾', 101);

-- ---------- 5. 缺陷命中记录（支撑学生画像 + 班级热力图） ----------
CREATE TABLE IF NOT EXISTS `daily_case_defect` (
    `id`          BIGINT      NOT NULL AUTO_INCREMENT,
    `record_id`   BIGINT      NOT NULL,
    `schedule_id` BIGINT      NOT NULL,
    `student_id`  BIGINT      NOT NULL,
    `segment_key` VARCHAR(40) DEFAULT NULL,
    `tag_code`    VARCHAR(40) NOT NULL,
    `level`       TINYINT     NOT NULL DEFAULT 1,
    `publish_date` DATE       DEFAULT NULL COMMENT '冗余排期日期，便于按时间统计',
    `created_at`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_defect_student` (`student_id`, `tag_code`),
    KEY `idx_defect_schedule` (`schedule_id`),
    KEY `idx_defect_tag` (`tag_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='病历缺陷命中记录（学生画像/班级热力图数据源）';
