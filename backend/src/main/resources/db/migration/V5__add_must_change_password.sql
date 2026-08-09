-- ============================================================
-- V5: 为 sys_user 增加 must_change_password 列
-- 用途：批量导入学生使用随机临时密码，首次登录强制改密
-- 安全：默认 0（否），导入时由 UserImportServiceImpl 置 1，改密后置 0
-- ============================================================

ALTER TABLE sys_user
    ADD COLUMN must_change_password TINYINT NOT NULL DEFAULT 0
    COMMENT '是否强制改密: 0否 1是' AFTER status;
