-- ============================================================
-- V5: 基础题库科室维度 + 教材电子书文件
-- 1. practice_question 增加 department（科室/模块）
-- 2. textbook 增加 file_url（电子书文件）与 page_count
-- 3. 为演示题目补充科室，并补充几道科室归属题
-- ============================================================

-- ---------- practice_question 增加科室 ----------
ALTER TABLE practice_question
    ADD COLUMN department VARCHAR(50) NULL COMMENT '所属科室/模块' AFTER question_type;

-- 为已有演示题按知识点回填科室
UPDATE practice_question SET department = '心血管内科' WHERE knowledge_tag IN ('胸痛鉴别', '冠心病', '心力衰竭', '高血压', '心律失常') AND department IS NULL;
UPDATE practice_question SET department = '呼吸内科'   WHERE knowledge_tag IN ('慢阻肺', '哮喘', '肺炎', '呼吸衰竭') AND department IS NULL;
UPDATE practice_question SET department = '诊断学'     WHERE knowledge_tag IN ('病史采集', '体格检查', '心电图判读', '实验室检查') AND department IS NULL;
UPDATE practice_question SET department = '综合'       WHERE department IS NULL;

-- ---------- textbook 增加电子书文件 ----------
ALTER TABLE textbook
    ADD COLUMN file_url  VARCHAR(255) NULL COMMENT '电子书文件地址' AFTER cover_url,
    ADD COLUMN page_count INT NOT NULL DEFAULT 0 COMMENT '页数' AFTER chapter_count;

-- ============================================================
-- 演示题库：为各「科室模块」补充题目（含难度进阶 1/2/3）
-- 幂等：按 title 判断
-- ============================================================

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '心血管内科', '冠心病', '急性ST段抬高型心肌梗死再灌注治疗的时间窗是？',
       JSON_ARRAY('发病后12小时内', '发病后24小时内', '发病后48小时内', '无时间限制'),
       '0', 'STEMI 应在发病后 12 小时内尽早行再灌注治疗（溶栓或急诊 PCI）。', 3, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '急性ST段抬高型心肌梗死再灌注%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'judgment', '心血管内科', '高血压', '高血压患者应常规进行继发性高血压的筛查。',
       JSON_ARRAY('正确', '错误'),
       '0', '对年轻、血压难控、有相关线索者应筛查继发性高血压，但并非所有患者均需常规筛查。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '高血压患者应常规进行继发性%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '呼吸内科', '慢阻肺', '诊断慢阻肺的金标准是？',
       JSON_ARRAY('胸部X线', '肺功能检查', '血气分析', '胸部CT'),
       '1', '肺功能检查（FEV1/FVC < 70%）是诊断慢阻肺的金标准。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '诊断慢阻肺的金标准是%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '呼吸内科', '哮喘', '哮喘急性发作的首选缓解药物是？',
       JSON_ARRAY('短效β2受体激动剂', '口服糖皮质激素', '茶碱', '白三烯受体拮抗剂'),
       '0', 'SABA 是缓解哮喘急性发作症状的首选药物。', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '哮喘急性发作的首选' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '诊断学', '心电图判读', '急性心肌梗死超急性期心电图最早出现的改变是？',
       JSON_ARRAY('T波高尖', '病理性Q波', 'ST段压低', 'QT延长'),
       '0', '超急性期最早出现高大、直立的 T 波，随后出现 ST 段抬高。', 3, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '急性心肌梗死超急性期心电图%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '诊断学', '病史采集', '问诊腹痛患者时，最先应询问的是？',
       JSON_ARRAY('疼痛诱因与部位', '既往手术史', '家族史', '职业史'),
       '0', '对腹痛，应先明确疼痛的部位、性质、诱因与放射，再追问伴随与既往史。', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '问诊腹痛患者时%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '综合', '酸碱平衡', '代谢性酸中毒时血浆 HCO3- 的改变是？',
       JSON_ARRAY('降低', '升高', '不变', '先升后降'),
       '0', '代酸时血浆 HCO3- 原发性降低，常伴 pH 下降。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '代谢性酸中毒时血浆 HCO3%' AND is_deleted = 0);

-- 演示教材电子书文件地址（file_url 指向 minio 或静态资源，此处占位示意）
UPDATE textbook SET file_url = CONCAT('/ebook/', id, '.pdf'), page_count = chapter_count * 20 WHERE file_url IS NULL;