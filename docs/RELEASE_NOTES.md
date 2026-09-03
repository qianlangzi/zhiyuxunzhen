# 发布说明 — 管理端 P0 安全加固 + 认证链路 + 导入学生强制改密

- **分支**：`admin`
- **提交**：`45cb587`
- **日期**：2026-08-09
- **变更规模**：50 个文件，+2335 / -86 行

---

## 概述

本次发布完成管理端（admin）P0 阶段核心建设，聚焦三条主线：**生产环境安全加固**、**管理端认证与权限链路**、**批量导入学生账号的默认密码风险修复**。后端 106 项测试全绿，admin 前端构建通过。

---

## 一、新功能

### 1.1 强制密码修改（Issue1 修复）
- 批量导入学生改用 `SecureRandom` 为每个学生生成独立随机临时密码（8 位，排除易混淆字符 `0/O/1/I/l`），不再使用固定密码 `123456`
- 导入时设置 `must_change_password=1`，学生首次登录强制改密
- 新增 `PUT /api/v1/auth/password` 改密端点，校验原密码 + 新旧不同 + 8-32 位字母数字混合
- `LoginResponse` 与 `UserInfoVO`（`/auth/me`）均返回 `mustChangePassword` 标志，前端页面刷新后可恢复状态
- 导入结果 `ImportResultVO` 新增 `successes` 列表，含每行临时密码供管理员分发

### 1.2 管理端认证链路
- 独立登录页 `Login.vue`，仅允许角色 2-5（教学秘书/教研室主任/管理员/运维）登录
- Pinia auth store（`stores/auth.ts`），token 以 `zhiyu_admin_` 前缀存储，与主应用隔离
- axios 拦截器（`api/http.ts`）：单飞 token 刷新 + 请求重放（最多一次）+ 会话一致性校验 + 并发失败去重提示
- 角色路由守卫（`router.ts`）：按角色驱动菜单与落地页

### 1.3 全局驾驶舱
- 新增 `GET /api/v1/admin/dashboard` 聚合接口
- `AdminDashboard.vue` 页面对接真实数据，Mock 区段已标注

---

## 二、安全加固

### 2.1 Spring Profile 强制校验
- 新增 `ProfileValidator`：启动时仅允许恰好一个 dev/test/prod，拒绝字面量 `${SPRING_PROFILES_ACTIVE}`
- `application.yml` 改为 `active: ${SPRING_PROFILES_ACTIVE}`（无默认值），强制显式激活

### 2.2 生产环境 fail-closed
- 新增 `ProdSecurityInitializer`（仅 prod 激活）：JWT secret / AI token 缺失或长度不足 32 字节时启动失败
- `DataInitializer` 标注 `@Profile({"dev","test"})`，demo 数据（含默认管理员账号）生产环境不初始化
- 已知占位符密钥（如 `dev-internal-token`）在生产环境被拒绝

### 2.3 精细化 RBAC
- `PermissionInterceptor` 精确匹配管理端接口权限：
  - `POST /admin/users/import` → 角色 2/4
  - `GET /admin/dashboard` → 角色 3/4/5
  - 其他 `/admin/**` → 角色 4
- `UserImportController` 路径由 `/api/v1/users/import` 迁移至 `/api/v1/admin/users/import`，纳入拦截器保护
- 拦截器使用 `UrlPathHelper.getPathWithinApplication()`，兼容未来 context-path 扩展

### 2.4 生产配置加固
- `docker-compose.prod.yml` 为 AI service 与 ai-worker 显式注入 `AI_CORS_ALLOWED_ORIGINS`、`JWT_SECRET`、`AI_INTERNAL_TOKEN`、`OPS_TOKEN`，并设 `ENV_MODE=prod`、`ENABLE_*_FALLBACK=false`
- Java 生产 CORS 拒绝 `*`、通配符、空值；允许来源必须显式指定
- multipart 全局 10MB 限制（与 `UserImportService` 文件大小上限对齐）
- Excel 上传限制：单文件 10MB / 单次 5000 行 / 单元格 100 字符 / 失败明细 100 条

---

## 三、数据库迁移

- 新增 Flyway 迁移 `V5__add_must_change_password.sql`：为 `sys_user` 表增加 `must_change_password` 列（`TINYINT NOT NULL DEFAULT 0`）
- `init.sql` 同步更新（仅用于首次初始化，已有库走 Flyway）

---

## 四、测试验证

| 测试套件 | 数量 | 状态 |
|---------|------|------|
| 后端全量 | 106 | ✅ 全绿 |
| AuthServiceImplTest（含新增 changePassword 4 项） | 17 | ✅ |
| AuthControllerIntegrationTest | 10 | ✅ |
| PermissionInterceptorIntegrationTest | 20 | ✅ |
| ProfileValidatorTest（新增） | 8 | ✅ |
| SecurityConfigCorsTest（新增） | 6 | ✅ |
| JwtUtilsPlaceholderSecretTest（新增） | 6 | ✅ |
| AI config 测试 | 11 | ✅ |
| admin 前端构建（`build:admin`） | — | ✅ |

---

## 五、已知限制与后续事项

1. **主应用前端（学生端）尚未对接后端真实认证 API**
   `front/src/views/Login.vue` 调用 `/api/v1/user/login`（后端不存在的路径）+ demo-token 回退。导入学生（role=0）的强制改密流程需待主应用对接 `/api/v1/auth/login` 后才能对学生生效。后端机制已完全就绪。

2. **后端拦截器未做 `mustChangePassword` 纵深防御**
   当前仅靠前端模态对话框阻断。持有有效 token 的用户理论上可绕过前端直接调其他 API。建议在认证拦截器层增加 fail-closed 检查（放行改密/登出端点）。

3. **refresh token 无服务端吊销**
   生产环境建议引入 token family/jti 或绝对会话限制。

4. **TLS 证书验证被禁用**
   git 全局配置 `http.sslVerify=false`，存在中间人风险，建议在代理证书问题解决后恢复。

---

## 六、主要新增文件

```
backend/src/main/java/com/zhiyu/config/ProdSecurityInitializer.java
backend/src/main/java/com/zhiyu/config/ProfileValidator.java
backend/src/main/java/com/zhiyu/service/dto/ChangePasswordRequest.java
backend/src/main/resources/db/migration/V5__add_must_change_password.sql
backend/src/test/java/com/zhiyu/common/util/JwtUtilsPlaceholderSecretTest.java
backend/src/test/java/com/zhiyu/config/ProfileValidatorTest.java
backend/src/test/java/com/zhiyu/config/SecurityConfigCorsTest.java
front/src/admin/api/auth.ts
front/src/admin/api/dashboard.ts
front/src/admin/api/http.ts
front/src/admin/components/ChangePasswordDialog.vue
front/src/admin/stores/auth.ts
front/src/admin/types/index.ts
front/src/admin/views/Login.vue
front/src/admin/views/NoAccess.vue
```
