-- ============================================================
-- V9: 补回 must_change_password 与 credential_version 列
-- ------------------------------------------------------------
-- 背景：admin 分支合并时引入了两个版本重复的迁移脚本
--   V5__add_must_change_password.sql 与 V6__add_credential_version.sql，
--   但由于版本 5/6 已被 practice_department/textbook_creator 占用，
--   这两列从未在库中真实落库，而新合并的认证链路代码（MustChangePasswordInterceptor、
--   AuthService、AdminService、UserImportService）都依赖这两列。
-- 处理：删除上述重复脚本，改为在本 V9 中一次性补齐，与已有 V1~V8 无缝衔接。
-- ============================================================

ALTER TABLE sys_user
    ADD COLUMN must_change_password TINYINT NOT NULL DEFAULT 0
    COMMENT '是否强制改密: 0否 1是' AFTER status;

ALTER TABLE sys_user
    ADD COLUMN credential_version INT NOT NULL DEFAULT 0
    COMMENT '凭证版本: 改密/重置密码时递增, JWT 携带此版本, 不匹配则拒绝' AFTER must_change_password;