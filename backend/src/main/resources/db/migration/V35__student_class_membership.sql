-- 学生-班级 多对多归属（一个学生可加入多个班级，一个班级有多个学生）
-- 替代原 sys_user.class_id 的单班级字段：加入班级统一写入本表。
CREATE TABLE IF NOT EXISTS student_class_membership (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_id BIGINT NOT NULL COMMENT '学生用户ID (sys_user.id, role=0)',
    class_id BIGINT NOT NULL COMMENT '教学班ID (teaching_class.id)',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_student_class (student_id, class_id),
    KEY idx_class_student (class_id, student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='学生-班级多对多归属';

-- 迁移既有单班级归属到多对多表
INSERT IGNORE INTO student_class_membership (student_id, class_id)
SELECT id, class_id FROM sys_user WHERE role = 0 AND class_id IS NOT NULL;