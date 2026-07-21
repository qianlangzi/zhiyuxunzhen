# Flutter Mobile 全链路联调实施计划

设计依据：`docs/superpowers/specs/2026-07-20-flutter-mobile-fullstack-integration-design.md`

## 成功标准

- 账号密码与手机验证码均可登录，后端角色决定学生/教师工作区。
- Flutter Remote 模式不再以 Mock 掩盖网络或服务错误。
- 学生和教师现有核心页面均有真实接口或明确“未实现/降级”状态。
- 问诊使用数据库病例上下文，SSE 可鉴权，消息和结果可持久化。
- 作业创建、学生提交、AI 批阅、教师复核形成闭环。
- 新库可由 `init.sql` 创建，已有库可由 Flyway 安全升级，演示数据可选导入。
- Backend、FastAPI、Flutter 自动测试和 Debug APK 构建通过。
- `docs/FLUTTER_MOBILE_FULLSTACK_GUIDE.md` 足够新手独立完成启动和排错。

## 阶段 1：基线与数据库

1. 运行现有 Maven、Flutter 和 FastAPI 检查，记录既有失败。
2. 引入 Flyway MySQL 依赖并建立 baseline/增量迁移。
3. 补齐班级、教师授权、作业目标班级、每日一例提交及必要索引/字段。
4. 更新空库 `deploy/mysql/init.sql`，新增可选 `deploy/mysql/seed/demo_data.sql`。
5. 在临时 MySQL 容器验证空库与迁移，不触碰当前数据目录。

## 阶段 2：双登录与 Flutter 会话

1. 增加短信验证码 DTO、Redis 服务、开发发送器和三类认证接口。
2. 保留原 `/auth/login` 兼容接口并补充认证测试。
3. Flutter 增加环境对象、统一响应/异常、TokenStore 和 Dio 拦截器。
4. AuthRepository 接入真实登录、短信、`/me`、刷新和登出。
5. 登录页增加两种方式；路由始终以后端角色为准。

## 阶段 3：学生真实数据

1. 增加公开病例详情、学生首页、每日一例提交、活动数据和作业详情接口。
2. 为后端 VO/DTO 和 Flutter DTO 编写映射测试。
3. 将首页、病例、每日一例、错题、活动页切换为异步真实 Repository。
4. 每页覆盖加载、空、错误和重试。

## 阶段 4：问诊与 AI

1. Spring Boot 增加会话详情/历史及 AI 内部上下文、消息保存接口。
2. FastAPI 使用 PyJWT 校验 Mobile JWT，使用 `sse-starlette` 输出 SSE。
3. 删除客户端消息拼装病例上下文的占位逻辑。
4. Flutter 创建会话后消费 SSE，并处理断线、降级、安全和完成事件。
5. 验证消息持久化和会话归属权限。

## 阶段 5：学生作业闭环

1. 补作业详情、提交结果、批阅查询和 AI 失败重试状态。
2. Flutter 增加/接通大病历提交和结果页面。
3. 验证格式打回、AI 批阅中、待复核和已完成状态。

## 阶段 6：教师真实数据

1. 增加教师首页、授权班级、作业列表/详情、批阅队列和洞察接口。
2. 强制病例归属、班级授权和批阅归属。
3. 接通教师病例创建/更新/发布/引用、作业创建和人工复核。
4. 将无可靠来源的功能显示为空或未实现，不生成随机统计。

## 阶段 7：验证与文档

1. 运行 Maven、pytest、Flutter analyze/test 和 Debug APK 构建。
2. 使用 Docker 服务做真实登录和核心接口冒烟测试。
3. 在模型/短信配置为空时验证明确降级。
4. 扫描剩余 Mock、占位和未实现点并分类。
5. 编写完整开发文档，逐接口、逐表、逐配置和逐文件说明。

## 风险控制

- 不执行 `docker compose down -v`，不删除 `data/mysql`。
- 所有数据库变更先在临时 MySQL 验证。
- 不修改 Vue Web 页面；保留旧登录路径兼容性。
- 不在日志、测试快照或文档中写入真实密钥。
- 不为单一页面引入通用框架；新增文件保持单一职责。
