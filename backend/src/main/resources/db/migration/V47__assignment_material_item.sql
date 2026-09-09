-- ============================================================
-- 作业任务项支持「资料附件」类型（MATERIAL）
-- 教师 publish 作业时可附带备课课件资料（PDF/PPT/MP4/MP3/图片），
-- 学生端作业详情展示「查看资料」任务并可标记完成。
-- ============================================================

-- ---------- assignment_item 增加备课资料引用 ----------
SET @ddl = (
    SELECT IF(COUNT(*) = 0,
        'ALTER TABLE `assignment_item` ADD COLUMN `lesson_material_id` BIGINT NULL COMMENT ''MATERIAL:备课资料ID(lesson_material.id)'' AFTER `textbook_id`',
        'SELECT 1')
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'assignment_item'
      AND column_name = 'lesson_material_id'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 索引：按资料反查引用它的作业任务项
SET @idx = (
    SELECT IF(COUNT(*) = 0,
        'ALTER TABLE `assignment_item` ADD INDEX `idx_ai_material` (`lesson_material_id`)',
        'SELECT 1')
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'assignment_item'
      AND index_name = 'idx_ai_material'
);
PREPARE stmt FROM @idx;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
