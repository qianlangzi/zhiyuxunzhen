-- ============================================================
-- V6: 为 sys_user 增加 credential_version 列
-- 用途：凭证版本机制，改密/重置密码时递增版本，使旧 token 因版本不匹配失效
-- 安全：防止攻击者用临时密码登录获取的旧 token 在合法用户改密后继续使用
-- ============================================================

ALTER TABLE sys_user
    ADD COLUMN credential_version INT NOT NULL DEFAULT 0
    COMMENT '凭证版本: 改密/重置密码时递增, JWT 携带此版本, 不匹配则拒绝' AFTER must_change_password;
