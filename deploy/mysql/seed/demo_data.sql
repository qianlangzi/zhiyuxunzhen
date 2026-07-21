-- 智愈寻真可选演示数据（密码统一为 123456）。
-- 仅用于本地开发；按用户名/业务标题判断是否已存在，不删除任何数据。

USE zhiyu_db;

INSERT INTO teaching_class (name, grade, status)
SELECT '临床 2203 班', '2022', 0
WHERE NOT EXISTS (
    SELECT 1 FROM teaching_class WHERE name = '临床 2203 班' AND grade = '2022'
);

SET @demo_class_id = (
    SELECT id FROM teaching_class WHERE name = '临床 2203 班' AND grade = '2022' LIMIT 1
);
SET @demo_password_hash = '$2a$10$Gurel74DaslD01Z85PFgJuntNZBLI/LLrgPN6IhgHkJKu7zpgEzWO';

INSERT INTO sys_user
    (username, password_hash, real_name, role, class_id, audit_status, status, phone)
SELECT 'teacher01', @demo_password_hash, '张老师', 1, NULL, 2, 0, '18500000001'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE username = 'teacher01');

INSERT INTO sys_user
    (username, password_hash, real_name, role, class_id, audit_status, status, phone)
SELECT 'student01', @demo_password_hash, '李同学', 0, @demo_class_id, 0, 0, '18500000002'
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE username = 'student01');

SET @demo_teacher_id = (SELECT id FROM sys_user WHERE username = 'teacher01' LIMIT 1);
SET @demo_student_id = (SELECT id FROM sys_user WHERE username = 'student01' LIMIT 1);

INSERT IGNORE INTO teacher_class_authorization (teacher_id, class_id)
VALUES (@demo_teacher_id, @demo_class_id);

INSERT INTO sp_case_config
    (creator_id, title, department, difficulty, patient_profile, hidden_disease,
     standard_path_json, preset_exams, knowledge_tags, is_public, reference_count,
     rating_avg, admin_audit_status, version, status)
SELECT
    @demo_teacher_id,
    '稳定型心绞痛问诊训练',
    '心血管内科',
    2,
    JSON_OBJECT('age', 59, 'gender', '男', 'chiefComplaint', '活动后胸闷 3 个月，近 1 周加重'),
    '稳定型心绞痛',
    JSON_ARRAY('确认胸痛诱因', '询问持续时间和缓解方式', '评估危险因素', '提出初步诊断'),
    JSON_ARRAY(JSON_OBJECT('name', '心电图', 'cost', 30, 'key', true)),
    JSON_ARRAY('胸痛鉴别', '冠心病', '病史采集'),
    1, 0, 4.8, 2, 1, 1
WHERE NOT EXISTS (
    SELECT 1 FROM sp_case_config
    WHERE creator_id = @demo_teacher_id AND title = '稳定型心绞痛问诊训练' AND is_deleted = 0
);

SET @demo_case_id = (
    SELECT id FROM sp_case_config
    WHERE creator_id = @demo_teacher_id AND title = '稳定型心绞痛问诊训练' AND is_deleted = 0
    LIMIT 1
);

INSERT INTO daily_case_schedule
    (case_id, publish_date, target_grade, question, options_json, standard_answer,
     answer_explanation, textbook_ref, status, created_by)
SELECT
    @demo_case_id,
    CURDATE(),
    NULL,
    '59 岁男性活动后胸闷，休息后缓解，最可能的诊断是什么？',
    JSON_ARRAY('稳定型心绞痛', '急性胃炎', '支气管哮喘', '肺结核'),
    '稳定型心绞痛',
    '活动诱发、休息缓解是稳定型心绞痛的典型线索。',
    '《内科学》心血管系统章节',
    2,
    @demo_teacher_id
WHERE NOT EXISTS (SELECT 1 FROM daily_case_schedule WHERE publish_date = CURDATE());

INSERT INTO assignment
    (teacher_id, case_id, title, description, require_medical_record, format_rule_json,
     anti_cheat_variables, deadline, allow_late_submit, status)
SELECT
    @demo_teacher_id,
    @demo_case_id,
    '心绞痛问诊与大病历训练',
    '完成问诊后提交一份结构化大病历。',
    1,
    JSON_OBJECT('requiredSections', JSON_ARRAY('主诉', '现病史', '初步诊断')),
    JSON_OBJECT(),
    DATE_ADD(NOW(), INTERVAL 7 DAY),
    1,
    1
WHERE NOT EXISTS (
    SELECT 1 FROM assignment
    WHERE teacher_id = @demo_teacher_id AND title = '心绞痛问诊与大病历训练' AND is_deleted = 0
);

SET @demo_assignment_id = (
    SELECT id FROM assignment
    WHERE teacher_id = @demo_teacher_id AND title = '心绞痛问诊与大病历训练' AND is_deleted = 0
    LIMIT 1
);

INSERT IGNORE INTO assignment_target_class (assignment_id, class_id)
VALUES (@demo_assignment_id, @demo_class_id);

INSERT INTO assignment_instance (assignment_id, student_id, case_id, variable_snapshot_json, status)
SELECT @demo_assignment_id, @demo_student_id, @demo_case_id, JSON_OBJECT(), 0
WHERE NOT EXISTS (
    SELECT 1 FROM assignment_instance
    WHERE assignment_id = @demo_assignment_id AND student_id = @demo_student_id AND is_deleted = 0
);
