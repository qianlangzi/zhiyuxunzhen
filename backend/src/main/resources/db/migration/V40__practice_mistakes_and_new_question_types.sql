-- ============================================================
-- V40: 刷题错题入库 + 新增主观题型（简答/论述）
-- ------------------------------------------------------------
-- 1. student_mistakes 增加 question_id，用于把「基础题刷题答错」写入错题本
--    （mistake_type='practice'），成长页/错题本即可渲染。
-- 2. practice_question.answer 由 VARCHAR(255) 放宽为 TEXT，容纳论述题长答案。
-- 3. 新增大题题库（short_answer 简答 / essay 论述），幂等按 title 判断。
-- ============================================================

-- ---------- 1. student_mistakes.question_id ----------
DROP PROCEDURE IF EXISTS add_mistake_question_id_if_missing;
DELIMITER $$
CREATE PROCEDURE add_mistake_question_id_if_missing()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'student_mistakes'
          AND column_name = 'question_id'
    ) THEN
        ALTER TABLE `student_mistakes`
            ADD COLUMN `question_id` BIGINT NULL COMMENT '关联基础题库题目（刷题错题时非空，case_id 用于病例错题）' AFTER `case_id`,
            ADD KEY `idx_question` (`question_id`);
    END IF;
END$$
DELIMITER ;
CALL add_mistake_question_id_if_missing();
DROP PROCEDURE add_mistake_question_id_if_missing;

-- ---------- 2. 放宽题目答案列 ----------
DROP PROCEDURE IF EXISTS widen_practice_answer_if_varchar;
DELIMITER $$
CREATE PROCEDURE widen_practice_answer_if_varchar()
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'practice_question'
          AND column_name = 'answer'
          AND data_type = 'varchar'
    ) THEN
        ALTER TABLE `practice_question` MODIFY COLUMN `answer` TEXT COMMENT '正确选项或参考答案（客观题存下标，主观题存参考答案文本）';
    END IF;
END$$
DELIMITER ;
CALL widen_practice_answer_if_varchar();
DROP PROCEDURE widen_practice_answer_if_varchar;

-- ============================================================
-- 3. 主观大题数据（简答 + 论述）
-- ============================================================

-- ---------- 简答题（short_answer） ----------
INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status, admin_audit_status)
SELECT 'short_answer', '心血管内科', '心力衰竭', '简述急性左心衰竭的紧急处理原则。',
       NULL,
       '半卧位、吸氧（高流量/无创通气）；快速利尿（呋塞米静注）；血管扩张剂（硝普钠、硝酸甘油）；必要时强心；原发病与诱因处理；烦躁时镇静。',
       '急性左心衰以抢救生命为目标：半卧位减少回心血量，高流量吸氧改善低氧，利尿剂减轻肺淤血，血管扩张剂降低前后负荷，呼衰严重时行无创正压通气，并积极处理诱因。', 2, 1, 2
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '%急性左心衰竭的紧急处理%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status, admin_audit_status)
SELECT 'short_answer', '呼吸内科', '肺炎', '简述社区获得性肺炎的抗菌治疗原则。',
       NULL,
       '尽早经验性治疗；根据病情严重程度选择口服或静脉给药；覆盖社区常见病原（肺炎链球菌、支原体等）；根据药敏及疗效及时调整；疗程一般 7～10 天。',
       'CAP 治疗强调尽早经验性覆盖常见病原体，轻症口服、重症静脉，48～72 小时评估疗效并根据培养/药敏调整，防止抗生素滥用与耐药。', 2, 1, 2
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '%社区获得性肺炎的抗菌治疗%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status, admin_audit_status)
SELECT 'short_answer', '诊断学', '病史采集', '简要说明胸痛的现病史询问要点。',
       NULL,
       '发作部位与性质；诱因与缓解方式（含含服硝酸甘油是否缓解）；发作频率、持续时间与病程演变；放射部位；伴随症状（气促、恶心、出汗等）；发作时的血压/心率及体位。',
       '现病史围绕胸痛的鉴别诊断展开，重点分辨心源性与非心源性胸痛，为后续体格检查与辅助检查提供方向。', 1, 1, 2
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '%胸痛的现病史询问%' AND is_deleted = 0);

-- ---------- 论述题（essay） ----------
INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status, admin_audit_status)
SELECT 'essay', '综合', '严重过敏反应', '论述严重过敏反应的识别要点与院内处理流程。',
       NULL,
       '识别：接触过敏原后快速起病的呼吸道（喉头水肿、喘鸣）、循环（低血压、晕厥）、皮肤黏膜（荨麻疹）；处理：立即停止接触并呼救，肌注肾上腺素为首选（成人 0.5mg 大腿外侧），吸氧、建立静脉通路快速补液，抗组胺药与糖皮质激素为辅；严重呼吸/循环衰竭时气管插管与循环支持；密切观察复发（双相反应）。',
       '严重过敏反应是时间敏感的紧急状态，肾上腺素肌注是唯一及时有效的抢救用药，切忌延误。流程强调识别-急救-支持-观察四步，防止双相反应漏诊。', 3, 1, 2
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '%严重过敏反应的识别要点%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status, admin_audit_status)
SELECT 'essay', '心血管内科', '急性冠脉综合征', '论述急性冠脉综合征的早期识别与急诊处理思路。',
       NULL,
       '识别：缺血性胸痛特点、心电图动态演变、肌钙蛋白升高；分类（STEMI/UA/NSTEMI）；处理：立即心电监护、吸氧，双联抗血小板（阿司匹林+替格瑞洛/氯吡格雷），抗凝，硝酸酯与镇痛；STEMI 尽快再灌注（PCI 首选或溶栓）；处理心律失常与心衰并发症，动态复查心电图与心肌标志物。',
       'ACS 处理黄金时间是早期再灌注。答题应体现「时间就是心肌」理念，从识别、抗栓、监测到再灌注的完整逻辑链。', 3, 1, 2
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '%急性冠脉综合征的早期识别%' AND is_deleted = 0);

INSERT INTO practice_question (question_type, department, knowledge_tag, title, options_json, answer, explanation, difficulty, status, admin_audit_status)
SELECT 'essay', '综合', '医患沟通', '论述如何在临床上向患者及家属告知不良预后或病情变化。',
       NULL,
       '原则：因人而异、循序渐进、共情与诚实并重；方式：选择安静私密环境，用通俗语言告知，留出理解与情绪反应时间，给予支持与后续计划，充分尊重患者知情权与自主选择；记录沟通过程。',
       '告知病情是最具挑战性的临床沟通场景。核心是「诚实 + 共情 + 支持」，既不能隐瞒，也要避免生硬，体现以患者为中心。', 2, 1, 2
WHERE NOT EXISTS (SELECT 1 FROM practice_question WHERE title LIKE '%如何向患者及家属告知不良预后%' AND is_deleted = 0);