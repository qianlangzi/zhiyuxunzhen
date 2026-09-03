-- 班级手动排序：记录教师在「班级管理」拖动调整的展示顺序（数值越小越靠前，0=未排序）
ALTER TABLE teaching_class
    ADD COLUMN sort_order INT NOT NULL DEFAULT 0 COMMENT '班级手动排序（0=未排序，越小越靠前）' AFTER invite_code;