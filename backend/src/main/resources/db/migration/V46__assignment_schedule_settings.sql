-- V46: 作业设置增强（学习通式：定时发布 / 补交窗口 / 总分 / 公布策略 / 提交次数 / 乱序 / 查重）
-- 配套改动：assignment 实体、AssignmentCreateDTO、AssignmentSettingsDTO（PUT /teacher/assignments/{id}/settings）
ALTER TABLE assignment
    ADD COLUMN start_time          DATETIME     NULL COMMENT '开始时间（定时发布），NULL=立即发布' AFTER allow_late_submit,
    ADD COLUMN late_deadline       DATETIME     NULL COMMENT '补交截止时间（allow_late_submit=1 时生效）' AFTER start_time,
    ADD COLUMN total_score         DECIMAL(6,2) NULL COMMENT '作业总分' AFTER late_deadline,
    ADD COLUMN score_publish_mode  VARCHAR(20)  NOT NULL DEFAULT 'IMMEDIATE' COMMENT '成绩公布 IMMEDIATE/AFTER_DEADLINE/MANUAL' AFTER total_score,
    ADD COLUMN answer_publish_mode VARCHAR(20)  NOT NULL DEFAULT 'AFTER_DEADLINE' COMMENT '答案公布 IMMEDIATE/AFTER_DEADLINE/MANUAL' AFTER score_publish_mode,
    ADD COLUMN shuffle_questions   TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '题目乱序' AFTER answer_publish_mode,
    ADD COLUMN max_attempts        INT          NOT NULL DEFAULT 1 COMMENT '允许提交次数' AFTER shuffle_questions,
    ADD COLUMN plagiarism_check    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '抄袭检测' AFTER max_attempts;
