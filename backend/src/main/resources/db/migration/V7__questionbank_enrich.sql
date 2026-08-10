-- ============================================================
-- V7: 题库丰富（多选/填空题型 + 各科室模块补充题目）
-- 1. 新增 multiple_choice（多选，answer 为逗号分隔的选项下标，如 "0,2"）
-- 2. 新增 fill_blank（填空，answer 为标准答案文本）
-- 3. 各科室模块补充题目，丰富题库量
-- 幂等：按 title 判断是否已存在
-- ============================================================

-- ---------- 心血管内科：多选/填空 ----------
INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'multiple_choice', '心血管内科', '冠心病', '急性心肌梗死的主要诊断依据包括？',
       JSON_ARRAY('典型胸痛', '心电图动态演变', '心肌坏死标志物升高', '发热'),
       '0,1,2', 'AMI 诊断主要依据典型缺血性胸痛、心电图动态演变及心肌坏死标志物（肌钙蛋白等）升高；发热非诊断依据。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '急性心肌梗死的主要诊断依据%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'fill_blank', '心血管内科', '高血压', '正常成人安静状态下的血压应低于____/____mmHg。',
       NULL, '120,80', '我国高血压诊断标准：收缩压≥140mmHg 或舒张压≥90mmHg；正常血压应低于 120/80mmHg。', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '正常成人安静状态下的血压%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'multiple_choice', '心血管内科', '心力衰竭', '慢性心力衰竭的常用治疗药物包括？',
       JSON_ARRAY('血管紧张素转换酶抑制剂', 'β受体阻滞剂', '利尿剂', '静脉补液扩容'),
       '0,1,2', '心衰治疗常用 ACEI/ARB、β受体阻滞剂、利尿剂等；急性心衰伴肺水肿时应利尿而非补液扩容。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '慢性心力衰竭的常用治疗药物%' AND is_deleted = 0);

-- ---------- 呼吸内科：多选/填空 ----------
INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'multiple_choice', '呼吸内科', '肺炎', '社区获得性肺炎常见的病原体包括？',
       JSON_ARRAY('肺炎链球菌', '支原体', '军团菌', '立克次体'),
       '0,1,2', 'CAP 常见病原体包括肺炎链球菌、支原体、军团菌、流感嗜血杆菌等；立克次体不属常见 CAP 病原。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '社区获得性肺炎常见的病原体%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'fill_blank', '呼吸内科', '慢阻肺', '诊断慢阻肺的肺功能标准为吸入支气管扩张剂后 FEV1/FVC < ____%。',
       NULL, '70', '吸入支气管扩张剂后 FEV1/FVC < 70% 提示持续气流受限，是诊断慢阻肺的必要条件。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '诊断慢阻肺的肺功能标准%' AND is_deleted = 0);

-- ---------- 诊断学：多选/填空 ----------
INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'multiple_choice', '诊断学', '体格检查', '叩诊音类型包括？',
       JSON_ARRAY('清音', '浊音', '实音', '过清音'),
       '0,1,2,3', '叩诊音包括清音、浊音、实音、鼓音、过清音等。', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '叩诊音类型包括%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'fill_blank', '诊断学', '实验室检查', '血常规中反映炎症或感染时升高的白细胞分类为____细胞。',
       NULL, '中性粒', '细菌感染时中性粒细胞常升高，病毒感染时多以淋巴细胞为主。', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '血常规中反映炎症或感染时升高%' AND is_deleted = 0);

-- ---------- 综合（基础医学）：多选 ----------
INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'multiple_choice', '综合', '酸碱平衡', '代谢性酸中毒的常见病因包括？',
       JSON_ARRAY('糖尿病酮症酸中毒', '严重腹泻', '慢性阻塞性肺疾病', '肾衰竭'),
       '0,1,3', '代酸常见于酮症酸中毒、严重腹泻（丢失 HCO3-）、肾衰竭；慢阻肺多引起呼吸性酸中毒。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '代谢性酸中毒的常见病因%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'multiple_choice', '综合', '水电解质紊乱', '低钾血症的临床表现包括？',
       JSON_ARRAY('肌无力', '肠麻痹', '心律失常', '手足抽搐'),
       '0,1,2', '低钾血症表现为肌无力、腹胀肠麻痹、心律失常；手足抽搐多见于低钙血症。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '低钾血症的临床表现包括%' AND is_deleted = 0);

-- ---------- 各科室补充单选题（丰富题库量） ----------
INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '心血管内科', '心律失常', '心房颤动最常见的病因是？',
       JSON_ARRAY('冠心病', '风湿性心脏病', '高血压病', '甲状腺功能亢进'),
       '2', '房颤最常见病因为高血压病，其次为冠心病、瓣膜病、甲亢等。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '心房颤动最常见的病因%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '心血管内科', '心力衰竭', '左心衰竭最典型的体征是？',
       JSON_ARRAY('下肢水肿', '肺部湿啰音', '颈静脉怒张', '肝大'),
       '1', '左心衰以肺循环淤血为主，最典型体征为双肺底湿啰音；下肢水肿、颈静脉怒张、肝大多为右心衰表现。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '左心衰竭最典型的体征%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '呼吸内科', '呼吸衰竭', 'Ⅱ型呼吸衰竭的诊断标准为？',
       JSON_ARRAY('PaO2<60mmHg，PaCO2正常', 'PaO2<60mmHg，PaCO2>50mmHg', 'PaO2>60mmHg，PaCO2>50mmHg', 'PaO2<60mmHg，PaCO2<50mmHg'),
       '1', 'Ⅱ型呼衰为缺氧伴二氧化碳潴留：PaO2<60mmHg 且 PaCO2>50mmHg。', 3, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE 'Ⅱ型呼吸衰竭的诊断标准%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '呼吸内科', '肺炎', '大叶性肺炎最常见的致病菌是？',
       JSON_ARRAY('金黄色葡萄球菌', '肺炎链球菌', '铜绿假单胞菌', '肺炎克雷伯菌'),
       '1', '大叶性肺炎最常见致病菌为肺炎链球菌，典型表现为铁锈色痰。', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '大叶性肺炎最常见的致病菌%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '诊断学', '心电图判读', '一度房室传导阻滞的心电图特点是？',
       JSON_ARRAY('PR间期>0.20s且恒定', 'PR间期逐渐延长', 'P波与QRS无关', 'QRS波群增宽'),
       '0', '一度房室传导阻滞为 PR 间期恒定 >0.20s；二度Ⅰ型 PR 逐渐延长；三度 P 与 QRS 无关。', 2, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '一度房室传导阻滞的心电图特点%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status)
SELECT 'single_choice', '诊断学', '病史采集', '主诉书写应遵循的原则是？',
       JSON_ARRAY('症状+持续时间', '诊断名词', '发病诱因', '既往史'),
       '0', '主诉应简明扼要，用症状或体征+持续时间概括患者最主要的不适，避免使用诊断名词。', 1, 1
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '主诉书写应遵循的原则%' AND is_deleted = 0);
