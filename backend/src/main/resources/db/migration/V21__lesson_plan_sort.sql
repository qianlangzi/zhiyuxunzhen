-- V21: 教案手动排序 —— 记录教师在「我的教案」拖动调整的展示顺序（越小越靠前，0=未排序）
ALTER TABLE lesson_plan ADD COLUMN sort_order INT NOT NULL DEFAULT 0 COMMENT '教案手动排序(0=未排序,越小越靠前)' AFTER priority;
