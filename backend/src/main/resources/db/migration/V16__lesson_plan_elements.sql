-- V16: 备课升级为教师教案创作台
-- 增加 对话确认的需求要素 / 学情目标班级 / 选用教材
ALTER TABLE lesson_plan ADD COLUMN teaching_elements_json JSON NULL COMMENT '对话确认的备课要素(主题/教材/学情/课时/重难点/风格)';
ALTER TABLE lesson_plan ADD COLUMN target_class_id BIGINT NULL COMMENT '学情目标班级ID(备课针对的班级,用于拉取真实学情)';
ALTER TABLE lesson_plan ADD COLUMN textbook_id BIGINT NULL COMMENT '选用教材ID';
ALTER TABLE lesson_plan ADD KEY idx_lesson_class (target_class_id);
