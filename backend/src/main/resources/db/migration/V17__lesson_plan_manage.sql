-- V17: 教案管理 —— 置顶 / 优先级（教师自用教案列表的整理能力）
-- is_top：是否置顶（1=置顶，0=否），置顶项在列表最前
-- priority：自定义优先级（0 默认，数值越大越靠前），便于手动排布常用教案
ALTER TABLE lesson_plan ADD COLUMN is_top TINYINT NOT NULL DEFAULT 0 COMMENT '是否置顶 0否 1是';
ALTER TABLE lesson_plan ADD COLUMN priority INT NOT NULL DEFAULT 0 COMMENT '自定义优先级(0默认,大者优先)';
ALTER TABLE lesson_plan ADD KEY idx_lesson_teacher_top (teacher_id, is_top, updated_at);