-- ============================================================
-- 恢复脚本：修复因旧版 init.sql 创建 must_change_password 列导致 V5 失败的 MySQL 卷
-- ============================================================
--
-- 适用场景：
--   MySQL 卷使用旧版 init.sql 初始化（init.sql 当时创建了 must_change_password 列），
--   Flyway V5 尝试 ADD COLUMN must_change_password 时因 duplicate column 失败，
--   flyway_schema_history 中残留 success=0 的 V5 记录，导致 V6 及后续迁移全部被阻塞。
--
-- 症状：
--   后端启动报错：Flyway: "Detected failed migration to version 5" 或
--   "Migration of schema ... to version 5 failed! Please remove failed migrations."
--
-- 使用方法：
--   1. 停止后端应用（docker compose stop backend）
--   2. 执行本脚本（注意容器名和数据库名）：
--      docker exec -i zhiyu-mysql mysql -uroot -p<password> zhiyu_db < deploy/mysql/recover-failed-v5.sql
--      或直接连接 MySQL：mysql -u root -p zhiyu_db < deploy/mysql/recover-failed-v5.sql
--   3. 重启后端应用（docker compose start backend），让 Flyway 重新执行 V5/V6
--   4. 后端启动成功后，再次执行本脚本以恢复 must_change_password 列值（POST-RESTART 段）
--   5. 检查后端日志确认 Flyway 正常启动
--
-- ============================================================
-- P0-2 修复（破坏性 bug 全部修正）：
--
--   1. 守卫条件（Guard）：仅当 flyway_schema_history 中存在 V5 success=0 记录时才执行
--      破坏性操作。健康库（V5 已成功）和第二次执行（恢复后 V5 无失败记录）均为 no-op。
--      旧脚本无此守卫，健康库和重复执行都会 drop 列、清零版本。
--
--   2. 不删除成功的 V5/V6 记录：旧脚本删除了 success=1 的记录，导致已成功的迁移被
--      回滚，列被 drop 后重新创建，所有列值丢失。
--
--   3. 不 drop credential_version 列：旧脚本无条件 drop credential_version，V6 重新
--      创建后所有用户版本重置为 0，导致冻结前/降权前的旧 token（version=0）重新有效。
--      本脚本绝不 drop credential_version。若列已存在则保留原值；若不存在则由 V6 创建。
--
--   4. 保留 must_change_password 列值：旧脚本 drop 后由 V5 重建，所有用户重置为 0，
--      导入学生的强制改密标记丢失。本脚本在 drop 前将列值备份到临时表，后端重启
--      V5 重建列后，再次执行本脚本的 POST-RESTART 段恢复原始值。
--
--   5. 真正幂等：第一次执行（V5 失败）→ 备份 + 删失败记录 + drop must_change_password。
--      第二次执行（V5 已成功，无失败记录）→ 全部 no-op。POST-RESTART 段可安全重复执行。
--
--   6. JWT 密钥轮换警告：若 credential_version 由 V6 首次创建（V5 失败导致 V6 被阻塞，
--      列此前不存在），所有用户版本为 0，旧 token（version=0 或无 version claim）将
--      与 DB 版本匹配。脚本末尾会检测此情况并输出警告，要求轮换 JWT 密钥。
-- ============================================================

-- ============================================================
-- 守卫：检测 V5 是否有失败记录
-- ============================================================
SET @v5_failed = (
    SELECT COUNT(*) FROM flyway_schema_history
    WHERE version = '5' AND success = 0
);

SELECT IF(@v5_failed > 0,
    'FAILED V5 migration detected. Proceeding with recovery...',
    'No failed V5 migration. Script is a no-op (healthy database or already recovered).'
) AS recovery_status;

-- ============================================================
-- STEP 1: 备份 must_change_password 列值（仅 V5 失败且列存在时）
-- ============================================================
-- 旧版 init.sql 创建了 must_change_password 列，V5 因 duplicate column 失败。
-- 我们需要 drop 此列让 V5 重新创建，但必须先备份列值（导入学生的强制改密标记）。
SET @mcp_exists = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'sys_user'
      AND column_name = 'must_change_password'
);

-- 仅在 V5 失败且列存在时备份（守卫：健康库不执行任何破坏性操作）
SET @do_backup = IF(@v5_failed > 0 AND @mcp_exists > 0, 1, 0);

-- 删除旧备份表（若存在），确保本次备份是最新的
SET @ddl = IF(@do_backup = 1,
    'DROP TABLE IF EXISTS _recovery_mcp_backup',
    'SELECT ''Skip backup cleanup: V5 not failed or column absent'' AS msg'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 创建备份表并复制当前列值
SET @ddl = IF(@do_backup = 1,
    'CREATE TABLE _recovery_mcp_backup AS SELECT id, must_change_password FROM sys_user',
    'SELECT ''Skip backup: V5 not failed or column absent'' AS msg'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 报告备份结果
SET @backup_count = IF(@do_backup = 1,
    (SELECT COUNT(*) FROM _recovery_mcp_backup),
    0
);
SELECT IF(@do_backup = 1,
    CONCAT('Backed up ', @backup_count, ' rows of must_change_password'),
    'No backup needed'
) AS backup_status;

-- ============================================================
-- STEP 2: 仅删除失败的 V5/V6 记录（不删除成功记录）
-- ============================================================
-- 安全操作：在健康库上删除 0 行（无 success=0 记录）
-- 旧脚本的 bug：同时删除 success=1 的记录，导致已成功的迁移被回滚
DELETE FROM flyway_schema_history WHERE version IN ('5', '6') AND success = 0;

-- ============================================================
-- STEP 3: Drop must_change_password 列（仅 V5 失败且列存在时）
-- ============================================================
-- V5 会在下次后端启动时重新创建此列
-- 守卫：@v5_failed=0 时不执行（健康库 / 已恢复库 / 第二次执行）
SET @should_drop_mcp = IF(@v5_failed > 0 AND @mcp_exists > 0, 1, 0);
SET @ddl = IF(@should_drop_mcp = 1,
    'ALTER TABLE sys_user DROP COLUMN must_change_password',
    'SELECT ''Skip drop must_change_password: V5 not failed or column absent'' AS msg'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ============================================================
-- STEP 4: 绝不 drop credential_version
-- ============================================================
-- 旧脚本的 bug：无条件 drop credential_version，V6 重建后所有用户版本重置为 0，
-- 导致冻结前/降权前的旧 token（version=0）重新有效。
--
-- 本脚本的处理策略：
--   - 若 credential_version 已存在（V6 已成功执行）→ 保留原值，不动
--   - 若 credential_version 不存在（V5 失败导致 V6 被阻塞）→ 由 V6 在后端重启时创建
--     此时所有用户版本为 0，旧 token 可能匹配 → 见 STEP 6 的 JWT 密钥轮换警告
--
-- 检测 credential_version 是否存在（用于 STEP 6 的警告逻辑）
SET @cv_exists = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'sys_user'
      AND column_name = 'credential_version'
);

-- ============================================================
-- STEP 5: 验证恢复结果
-- ============================================================
SELECT '=== Recovery Summary ===' AS '';
SELECT version, description, success FROM flyway_schema_history
WHERE version IN ('5', '6') ORDER BY version;

SELECT
    @v5_failed AS v5_had_failed,
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'sys_user'
       AND column_name = 'must_change_password') AS must_change_password_exists,
    @cv_exists AS credential_version_existed_before,
    IF(@v5_failed > 0,
        'Restart backend now. Flyway will re-run V5 (create must_change_password) and V6 (create credential_version if absent).',
        'No action needed. Database is healthy or already recovered.'
    ) AS next_action;

-- ============================================================
-- STEP 6: JWT 密钥轮换警告
-- ============================================================
-- 若 V5 失败导致 V6 从未执行，credential_version 此前不存在。V6 首次创建后
-- 所有用户版本为 0，旧 token（version=0 或无 version claim）将与 DB 版本匹配，
-- 包括冻结前、降权前的 token。
--
-- 缓解措施：轮换 JWT 密钥使所有旧 token 立即失效。
-- 操作：修改后端配置中的 jwt.secret（或对应环境变量），重启后端。
SET @jwt_warning = IF(@v5_failed > 0 AND @cv_exists = 0,
    'WARNING: credential_version did not exist before recovery. After V6 creates it (default=0), old tokens with version=0 will be valid again. You MUST rotate the JWT signing key to invalidate all pre-recovery tokens. Update jwt.secret in backend config and restart.',
    'OK: credential_version already existed or V5 did not fail. No JWT key rotation needed.'
);
SELECT @jwt_warning AS jwt_security_warning;

SELECT IF(@v5_failed > 0,
    'Recovery complete. Restart backend to let Flyway re-run V5/V6, then run POST-RESTART section.',
    'No-op. Database is healthy or already recovered.'
) AS result;

-- ============================================================
-- POST-RESTART 段：恢复 must_change_password 列值
-- ============================================================
-- ⚠️ 此段应在后端重启（V5 已重新创建 must_change_password 列）后执行！
-- 可安全重复执行：若备份表不存在或列不存在，操作为 no-op。
--
-- 执行方式：
--   mysql -u root -p zhiyu_db < deploy/mysql/recover-failed-v5.sql
--   （第二次执行：@v5_failed=0 → STEP 1-4 全部 no-op，仅 POST-RESTART 段生效）
--
-- 原理：第二次执行时 V5 已成功（无 failed 记录），守卫跳过所有破坏性操作。
-- 但备份表 _recovery_mcp_backup 仍存在，且 must_change_password 列已被 V5 重建。
-- 以下 UPDATE 将备份的列值恢复到新建的列中。

-- 检查备份表和新列是否同时存在
SET @backup_exists = (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = DATABASE()
      AND table_name = '_recovery_mcp_backup'
);
SET @mcp_exists_now = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'sys_user'
      AND column_name = 'must_change_password'
);

-- 仅当备份表和列同时存在时执行恢复（幂等：无备份表时 no-op）
SET @do_restore = IF(@backup_exists > 0 AND @mcp_exists_now > 0, 1, 0);
SET @ddl = IF(@do_restore = 1,
    'UPDATE sys_user u INNER JOIN _recovery_mcp_backup b ON u.id = b.id SET u.must_change_password = b.must_change_password',
    'SELECT ''Skip restore: backup table or column absent (no-op)'' AS msg'
);
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 报告恢复结果
SET @restored_count = IF(@do_restore = 1,
    (SELECT COUNT(*) FROM sys_user u INNER JOIN _recovery_mcp_backup b ON u.id = b.id WHERE u.must_change_password = b.must_change_password),
    0
);
SELECT IF(@do_restore = 1,
    CONCAT('Restored must_change_password for ', @restored_count, ' users'),
    'No restore needed (no backup table or column absent)'
) AS restore_status;

-- 恢复完成后可选择清理备份表（取消注释执行）
-- DROP TABLE IF EXISTS _recovery_mcp_backup;

SELECT '=== Post-Restart Restore Complete ===' AS '';
SELECT
    (SELECT COUNT(*) FROM sys_user WHERE must_change_password = 1) AS users_needing_password_change,
    (SELECT COUNT(*) FROM sys_user WHERE must_change_password = 0 OR must_change_password IS NULL) AS users_ok;
