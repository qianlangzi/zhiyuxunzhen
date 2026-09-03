-- ============================================================
-- 教材中心 + 基础题训练 + 薄弱知识点智能推荐
-- 表结构：textbook / practice_question / student_practice_record
-- 演示数据：幂等插入（按标题/知识点判断是否已存在）
-- ============================================================

-- ---------- 教材表 ----------
CREATE TABLE IF NOT EXISTS textbook (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    title            VARCHAR(200) NOT NULL,
    edition          VARCHAR(50),
    department       VARCHAR(50)  COMMENT '学科/科室',
    author           VARCHAR(100),
    publisher        VARCHAR(100),
    cover_url        VARCHAR(255),
    description      TEXT,
    knowledge_tags   JSON,
    chapter_count    INT          NOT NULL DEFAULT 0,
    status           TINYINT      NOT NULL DEFAULT 1 COMMENT '0下架 1上架',
    is_deleted       TINYINT      NOT NULL DEFAULT 0,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_department (department),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='教材表';

-- ---------- 基础题题库表 ----------
CREATE TABLE IF NOT EXISTS practice_question (
    id                  BIGINT       NOT NULL AUTO_INCREMENT,
    question_type       VARCHAR(20)  NOT NULL DEFAULT 'single_choice' COMMENT 'single_choice/judgment',
    knowledge_tag       VARCHAR(100) NOT NULL,
    title               TEXT         NOT NULL,
    options_json        JSON,
    answer              VARCHAR(255) NOT NULL COMMENT '正确选项或答案',
    explanation         TEXT,
    difficulty          TINYINT      NOT NULL DEFAULT 2 COMMENT '1简单 2标准 3困难',
    source_textbook_id  BIGINT       COMMENT '关联教材',
    status              TINYINT      NOT NULL DEFAULT 1,
    is_deleted          TINYINT      NOT NULL DEFAULT 0,
    created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_knowledge_tag (knowledge_tag),
    KEY idx_type (question_type),
    KEY idx_difficulty (difficulty)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='基础题题库表';

-- ---------- 学生基础题练习记录表 ----------
CREATE TABLE IF NOT EXISTS student_practice_record (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    student_id       BIGINT       NOT NULL,
    question_id      BIGINT       NOT NULL,
    selected_answer  VARCHAR(255),
    is_correct       TINYINT(1),
    answered_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_student (student_id),
    KEY idx_question (question_id),
    KEY idx_answered (answered_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生基础题练习记录表';

-- ============================================================
-- 演示数据（幂等）
-- ============================================================

-- ---------- 教材 ----------
INSERT INTO textbook (title, edition, department, author, publisher, knowledge_tags, chapter_count, status)
SELECT '内科学', '第9版', '心血管内科', '葛均波、王辰', '人民卫生出版社',
       JSON_ARRAY('胸痛鉴别', '冠心病', '心律失常', '心力衰竭', '高血压'),
       105, 1
WHERE NOT EXISTS (SELECT 1 FROM textbook WHERE title = '内科学' AND is_deleted = 0);

INSERT INTO textbook (title, edition, department, author, publisher, knowledge_tags, chapter_count, status)
SELECT '诊断学', '第9版', '综合', '万学红、卢雪峰', '人民卫生出版社',
       JSON_ARRAY('病史采集', '体格检查', '心电图判读', '实验室检查'),
       88, 1
WHERE NOT EXISTS (SELECT 1 FROM textbook WHERE title = '诊断学' AND is_deleted = 0);

INSERT INTO textbook (title, edition, department, author, publisher, knowledge_tags, chapter_count, status)
SELECT '病理生理学', '第9版', '基础医学', '王建枝、殷莲华', '人民卫生出版社',
       JSON_ARRAY('酸碱平衡', '缺氧', '发热', '休克', '水电解质紊乱'),
       120, 1
WHERE NOT EXISTS (SELECT 1 FROM textbook WHERE title = '病理生理学' AND is_deleted = 0);

INSERT INTO textbook (title, edition, department, author, publisher, knowledge_tags, chapter_count, status)
SELECT '药理学', '第9版', '基础医学', '杨宝峰、陈建国', '人民卫生出版社',
       JSON_ARRAY('抗菌药物', '降压药', '抗心律失常药', '抗凝药'),
       96, 1
WHERE NOT EXISTS (SELECT 1 FROM textbook WHERE title = '药理学' AND is_deleted = 0);

INSERT INTO textbook (title, edition, department, author, publisher, knowledge_tags, chapter_count, status)
SELECT '内科学·心血管系统疾病诊疗规范', '2023', '心血管内科', '中华医学会心血管病学分会', '人民卫生出版社',
       JSON_ARRAY('冠心病', '急性冠脉综合征', '心力衰竭'),
       42, 1
WHERE NOT EXISTS (SELECT 1 FROM textbook WHERE title = '内科学·心血管系统疾病诊疗规范' AND is_deleted = 0);

INSERT INTO textbook (title, edition, department, author, publisher, knowledge_tags, chapter_count, status)
SELECT '呼吸内科学', '第9版', '呼吸内科', '钟南山', '人民卫生出版社',
       JSON_ARRAY('慢阻肺', '哮喘', '肺炎', '呼吸衰竭'),
       78, 1
WHERE NOT EXISTS (SELECT 1 FROM textbook WHERE title = '呼吸内科学' AND is_deleted = 0);

SET @tb_neike = (SELECT id FROM textbook WHERE title = '内科学' AND is_deleted = 0 LIMIT 1);
SET @tb_zhenduan = (SELECT id FROM textbook WHERE title = '诊断学' AND is_deleted = 0 LIMIT 1);
SET @tb_bingli = (SELECT id FROM textbook WHERE title = '病理生理学' AND is_deleted = 0 LIMIT 1);
SET @tb_yaoli = (SELECT id FROM textbook WHERE title = '药理学' AND is_deleted = 0 LIMIT 1);
SET @tb_xxg = (SELECT id FROM textbook WHERE title = '内科学·心血管系统疾病诊疗规范' AND is_deleted = 0 LIMIT 1);
SET @tb_huxi = (SELECT id FROM textbook WHERE title = '呼吸内科学' AND is_deleted = 0 LIMIT 1);

-- ---------- 基础题（胸痛鉴别 / 冠心病） ----------
INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '胸痛鉴别',
       '活动时诱发、休息或含服硝酸甘油后缓解的胸骨后压榨样疼痛，最可能的诊断是？',
       JSON_ARRAY('稳定型心绞痛', '急性心肌梗死', '主动脉夹层', '肺栓塞'),
       '0', '活动诱发、休息可缓解是稳定型心绞痛的典型特点；急性心梗疼痛更剧烈且持续。', 2, @tb_neike
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '胸痛鉴别' AND title LIKE '活动时诱发%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '胸痛鉴别',
       '突发撕裂样胸痛，伴两侧脉搏不对称，应首先考虑？',
       JSON_ARRAY('心绞痛', '主动脉夹层', '气胸', '心包炎'),
       '1', '撕裂样疼痛伴脉搏不对称是主动脉夹层的典型线索，需紧急排查。', 2, @tb_neike
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '胸痛鉴别' AND title LIKE '突发撕裂样胸痛%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'judgment', '胸痛鉴别',
       '上腹部疼痛伴大汗，即使无典型胸痛也需警惕急性冠脉综合征的不典型表现。',
       JSON_ARRAY('正确', '错误'),
       '0', 'ACS 可表现为上腹痛、恶心等不典型症状，易误诊为消化系统疾病。', 1, @tb_neike
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '胸痛鉴别' AND title LIKE '上腹部疼痛伴大汗%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '冠心病',
       '稳定型心绞痛的首选缓解药物是？',
       JSON_ARRAY('阿司匹林', '硝酸甘油', '美托洛尔', '阿托伐他汀'),
       '1', '硝酸甘油舌下含服是稳定型心绞痛急性发作的首选缓解药物。', 1, @tb_yaoli
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '冠心病' AND title LIKE '稳定型心绞痛的首选%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '冠心病',
       '急性心肌梗死患者心电图早期最具特征性的改变是？',
       JSON_ARRAY('T 波倒置', 'ST 段弓背向上抬高', '病理性 Q 波', 'QT 间期延长'),
       '1', '急性期心肌梗死以 ST 段弓背向上抬高等超急性期改变最具特征性。', 2, @tb_neike
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '冠心病' AND title LIKE '急性心肌梗死患者心电图%' AND is_deleted = 0);

-- ---------- 基础题（病史采集 / 体格检查） ----------
INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '病史采集',
       '采集胸痛病史时，下列哪项不属于必须问清的要素？',
       JSON_ARRAY('诱因与缓解方式', '发作频率与持续时间', '放射部位', '患者家属职业'),
       '3', '胸痛病史应重点询问诱因、频率、持续时间、性质、放射部位与伴随症状。', 1, @tb_zhenduan
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '病史采集' AND title LIKE '采集胸痛病史时%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'judgment', '病史采集',
       '问诊时采用开放式问题比封闭式问题更容易获得完整病史信息。',
       JSON_ARRAY('正确', '错误'),
       '0', '开放式问题鼓励患者自由叙述，有助于完整采集病史。', 1, @tb_zhenduan
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '病史采集' AND title LIKE '问诊时采用开放式%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '心电图判读',
       '窦性心律的 P 波在 II 导联的表现是？',
       JSON_ARRAY('倒置', '直立', '消失', '双向'),
       '1', '正常窦性 P 波在 II 导联直立，aVR 导联倒置。', 2, @tb_zhenduan
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '心电图判读' AND title LIKE '窦性心律的 P 波%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '心力衰竭',
       '心力衰竭最常见的症状是？',
       JSON_ARRAY('心悸', '呼吸困难', '发热', '水肿（早期）'),
       '1', '活动后呼吸困难是心力衰竭最常见、最典型的早期表现。', 2, @tb_neike
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '心力衰竭' AND title LIKE '心力衰竭最常见的症状%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '慢阻肺',
       '慢性阻塞性肺疾病气流受限的主要特征是？',
       JSON_ARRAY('可逆性气流受限', '不可逆或部分可逆气流受限', '单纯气道高反应', '不伴肺气肿'),
       '1', '慢阻肺以持续气流受限为特征，多呈进行性、不完全可逆。', 2, @tb_huxi
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '慢阻肺' AND title LIKE '慢性阻塞性肺疾病气流受限%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, knowledge_tag, title, options_json, answer, explanation, difficulty, source_textbook_id)
SELECT 'single_choice', '高血压',
       '抗高血压药物中，属于钙通道阻滞剂的是？',
       JSON_ARRAY('氨氯地平', '缬沙坦', '美托洛尔', '氢氯噻嗪'),
       '0', '氨氯地平为二氢吡啶类钙通道阻滞剂；缬沙坦为 ARB，美托洛尔为 β 受体阻滞剂。', 1, @tb_yaoli
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE knowledge_tag = '高血压' AND title LIKE '抗高血压药物中%' AND is_deleted = 0);