-- ============================================================
-- 班级资料库（class_material）
-- 教师在班级详情「资料」板块维护的班级级资料：
--   source_type = upload   教师自行上传（PDF/PPT/Word/MP4/MP3/图片/TXT 等）
--   source_type = textbook 引用教材库教材（只存引用，不复制文件）
-- 学生端在「我的课程-班级详情」按班级查看，随存随看，不进待办闭环。
-- ============================================================

CREATE TABLE IF NOT EXISTS `class_material` (
    `id`            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    `class_id`      BIGINT       NOT NULL COMMENT '班级ID(teaching_class.id)',
    `source_type`   VARCHAR(16)  NOT NULL DEFAULT 'upload' COMMENT '来源：upload上传 / textbook引用教材',
    `material_type` VARCHAR(16)  NOT NULL COMMENT '类型：pdf/ppt/doc/docx/txt/epub/mp4/mp3/image/link',
    `title`         VARCHAR(200) NOT NULL COMMENT '资料标题',
    `file_url`      VARCHAR(500) NULL COMMENT '文件访问地址（textbook 引用时为空）',
    `object_key`    VARCHAR(300) NULL COMMENT '存储相对路径（如 materials/xxx.pdf）',
    `textbook_id`   BIGINT       NULL COMMENT '引用教材ID(textbook.id)，source_type=textbook 时有值',
    `duration_sec`  INT          NULL COMMENT '音视频时长（秒）',
    `creator_id`    BIGINT       NOT NULL COMMENT '上传/引用的教师ID',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `is_deleted`    TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除：0正常 1删除',
    PRIMARY KEY (`id`),
    INDEX `idx_cm_class` (`class_id`, `is_deleted`, `id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci
  COMMENT = '班级资料库';
