-- ============================================================
-- V42: 训练→错题本闭环（连续做对数 / 累计答错数 / 需加强标记）
-- ------------------------------------------------------------
-- 现状：刷题答错即写入错题本（mistake_type='practice'），答对后无任何
-- 更新，错题只进不出。本迁移增加三个计数/标记列，支撑状态机闭环：
--   consecutive_correct  进入错题本后「连续答对」次数，达到阈值(2)判已掌握
--   wrong_count          进入错题本后累计「答错」次数，>=2 置 focus_flag 需加强
--   focus_flag           0普通 1需加强（反复做错提示聚焦）
-- ============================================================

DROP PROCEDURE IF EXISTS add_mistake_loop_columns;
DELIMITER $$
CREATE PROCEDURE add_mistake_loop_columns()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'student_mistakes'
          AND column_name = 'consecutive_correct'
    ) THEN
        ALTER TABLE `student_mistakes`
            ADD COLUMN `consecutive_correct` INT NOT NULL DEFAULT 0 COMMENT '进入错题本后连续答对次数，达到阈值判已掌握' AFTER `resolved_status`,
            ADD COLUMN `wrong_count` INT NOT NULL DEFAULT 0 COMMENT '进入错题本后累计答错次数' AFTER `consecutive_correct`,
            ADD COLUMN `focus_flag` TINYINT NOT NULL DEFAULT 0 COMMENT '0普通 1需加强（连续答错>=2）' AFTER `wrong_count`;
    END IF;
END$$
DELIMITER ;
CALL add_mistake_loop_columns();
DROP PROCEDURE add_mistake_loop_columns;