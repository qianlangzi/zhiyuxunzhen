-- ============================================================
-- V45: 学生端「待办 ↔ 我的课程」联动 —— 资料任务完成进度
-- ------------------------------------------------------------
-- 现状：教师发布备课资料（lesson_publish, material_only=1）后，学生端
-- 没有任何「完成」记录表，资料任务看过与否无从判定，导致：
--   1. 资料任务永远进不了待办的清除链路（看完不会消失）；
--   2. 「我的课程」无法按班聚合待办数（作业待办 + 资料待办）。
-- 本迁移新增 lesson_task_progress：学生 × 资料发布 唯一，标记完成。
-- 注意：material_only=0 的发布走作业实例链路（assignment_instance），
--       不在此表登记，避免同一件事两头计数。
-- ============================================================

CREATE TABLE IF NOT EXISTS `lesson_task_progress` (
    `id`          BIGINT  NOT NULL AUTO_INCREMENT,
    `publish_id`  BIGINT  NOT NULL COMMENT '备课发布ID（lesson_publish.id）',
    `student_id`  BIGINT  NOT NULL COMMENT '学生用户ID',
    `status`      TINYINT NOT NULL DEFAULT 0 COMMENT '0未完成 1已完成',
    `completed_at` DATETIME DEFAULT NULL COMMENT '完成时间',
    `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_publish_student` (`publish_id`, `student_id`),
    KEY `idx_student_status` (`student_id`, `status`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci
  COMMENT = '学生资料任务完成进度（待办清除与课程角标联动）';
