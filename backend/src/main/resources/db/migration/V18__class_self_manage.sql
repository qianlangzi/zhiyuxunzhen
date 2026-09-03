-- 教师自建班级：教学班归属教师(teacher_id) + 学生加入邀请码(invite_code)
-- 管理员预置的班级 teacher_id 为 NULL，仍由 teacher_class_authorization 授权给教师。
ALTER TABLE teaching_class
    ADD COLUMN teacher_id  BIGINT NULL COMMENT '创建/归属教师ID（管理员预置为NULL）' AFTER grade,
    ADD COLUMN invite_code VARCHAR(32) NULL COMMENT '学生加入班级邀请码（唯一）' AFTER teacher_id;

CREATE UNIQUE INDEX uk_class_invite_code ON teaching_class (invite_code);