# 智愈寻真 Flutter Mobile 全链路联调设计

日期：2026-07-20  
范围：Flutter Mobile、Spring Boot、FastAPI、MySQL、Redis、Milvus 与 Docker 联调  
不在范围：Vue Web 页面改造

## 1. 背景与目标

当前 Flutter 学生端和教师端已具备主要页面，但登录、病例、作业、批阅、统计和问诊等页面大量直接读取 `MockData`。Dio 客户端存在但未进入 Repository；Spring Boot 已实现部分接口，缺少教师列表、批阅队列、统计和手机号验证码登录等接口；FastAPI 能提供 SSE 和 AI 能力，但问诊上下文仍有占位拼装，部分未配置模型时的降级结果容易被误认为真实 AI 结论；MySQL 已运行并有 12 张表和 3 个演示用户，但初始化脚本只会在空数据目录首次执行，缺少现有数据库的版本化迁移机制。

本期目标是打通 Flutter → Spring Boot/FastAPI → MySQL/Redis/Milvus 的完整链路：

1. 支持账号密码与手机号验证码两种登录方式。
2. 登录后的页面由后端真实角色决定：学生进入学生端，教师进入教师端，管理角色拒绝进入 Mobile。
3. 现有 Mobile 页面只要存在可靠业务数据来源，就改为真实接口。
4. 缺失但可由现有业务表可靠计算的接口在 Spring Boot 补齐。
5. AI 问诊使用真实病例上下文，消息和结果持久化。
6. 外部短信和模型配置允许留空；缺失时功能明确提示未配置或降级，不伪造成功。
7. 提供全新建库、已有库迁移和可选演示数据脚本。
8. 产出一份面向新手的完整开发文档。

## 2. 设计约束与不过度设计原则

- 只修改 `mobile/`、`backend/`、`ai/`、数据库/Docker 配置和相关文档，不改 Vue Web 页面。
- 复用现有 Spring Boot、MyBatis Plus、Redis、FastAPI、Dio、Riverpod 和 GoRouter，不重写技术栈。
- Flutter 页面不直接调用 Dio；页面只依赖 Controller/Provider 和 Repository。
- 不引入独立 API 网关、消息队列、服务注册中心、通用代码生成器或第二套用户系统。
- 能通过现有表关联查询得到的数据不新建重复表。
- 只有现有结构无法表达班级关系、作业目标班级和每日一例提交时才新增表。
- 不将真实网络失败静默回退为 Mock。
- 不复制来源不明的 GitHub 项目代码；优先使用许可证兼容、持续维护的成熟依赖。
- 每项改动必须能对应到具体 Mobile 页面、接口、安全要求或联调问题。

## 3. 方案选择

采用纵向链路逐条打通：数据库/接口/Mobile 页面在同一业务链路内一起完成并验证。顺序为认证、学生病例与每日一例、问诊 SSE、学生作业、教师病例与作业、教师批阅与统计、剩余 Mock 清理、Docker 真机联调。

未采用“先写完全部后端再统一改 Flutter”，因为问题会集中到最后联调。未采用 OpenAPI 全量生成 Flutter 客户端，因为当前后端 VO 与展示模型差异明显，生成代码仍需大量适配，并会增加本期复杂度。

## 4. 总体架构

```text
Flutter 页面
  → Riverpod Controller / Async 状态
  → Repository
  → Remote Data Source
  → Dio HTTP 客户端
      → Spring Boot：认证、病例、作业、统计、权限和持久化
      → FastAPI：问诊 SSE、AI 评估、批阅和生成
          → Spring Boot 内部接口：读取病例上下文、保存消息和回调结果
              → MySQL / Redis / Milvus
```

职责边界：

- Flutter：输入、展示、加载/空/错误/重试状态和角色路由。
- Spring Boot：用户身份、业务权限、事务、业务数据和 AI 内部接口。
- FastAPI：模型调用、SSE 编排、RAG、结构化 AI 输出和业务中台回调。
- MySQL：长期业务数据。
- Redis：短信验证码、频率限制和短期状态。
- Milvus：教材向量检索，不保存核心业务记录。

## 5. 配置与数据模式

Flutter 使用编译期参数：

```text
USE_MOCK=false
API_BASE_URL=http://10.0.2.2:8080
AI_BASE_URL=http://10.0.2.2:8000
```

- 默认开发运行目标改为真实接口。
- `USE_MOCK=true` 仅用于离线演示和特定 Widget 测试。
- Remote 模式失败时展示错误，不回退 Mock。
- 暂无可靠数据来源的功能必须标注“暂未实现”或“演示数据”。

允许留空的外部配置：

```text
SMS_PROVIDER=
SMS_ACCESS_KEY=
SMS_SECRET_KEY=
SMS_SIGN_NAME=
SMS_TEMPLATE_CODE=
SMS_CODE_SECRET=
LLM_BASE_URL=
LLM_API_KEY=
LLM_MODEL=
VISION_BASE_URL=
VISION_API_KEY=
VISION_MODEL=
EMBEDDING_BASE_URL=
EMBEDDING_API_KEY=
EMBEDDING_MODEL=
```

必需配置缺失时服务应拒绝启动并说明原因；短信和模型等可选配置缺失时服务仍可启动，对应功能返回明确状态。

## 6. 认证与身份路由

### 6.1 接口

| 方法 | 路径 | 功能 |
| --- | --- | --- |
| POST | `/api/v1/auth/login/password` | 用户名和密码登录 |
| POST | `/api/v1/auth/sms-code` | 获取手机验证码 |
| POST | `/api/v1/auth/login/sms` | 手机号和验证码登录 |
| POST | `/api/v1/auth/login` | 兼容原用户名密码登录 |
| POST | `/api/v1/auth/refresh` | 刷新 access token |
| GET | `/api/v1/auth/me` | 获取当前真实用户 |
| POST | `/api/v1/auth/logout` | 登出 |

### 6.2 角色规则

- `role = 0`：学生工作区。
- `role = 1`：教师工作区。
- `role >= 2`：Mobile 拒绝登录并提示使用 Web 管理端。
- Flutter 登录页入口只影响输入提示，不决定身份。
- 登录、短信登录、应用重启和 token 刷新后均以 `/auth/me` 返回的角色路由。

### 6.3 Token

- access token 与 refresh token 使用 `flutter_secure_storage`。
- 普通用户显示信息可使用 `SharedPreferences` 缓存，但不能作为权限依据。
- Dio 自动加入 Bearer token。
- access token 过期后执行一次共享刷新；并发失败请求等待同一个刷新结果。
- refresh token 失效时清理会话并返回登录页。

### 6.4 手机验证码

- 仅允许已存在的手机号登录，不实现自动注册。
- 验证码为随机 6 位数，有效期 5 分钟。
- 同一手机号 60 秒内不能重复获取，每小时最多 5 次，最多错误尝试 5 次。
- Redis 保存验证码摘要、次数和过期时间；成功后立即删除。
- 开发环境在日志和响应 `devCode` 中提供验证码。
- 生产环境绝不返回验证码；未配置短信厂商时返回“短信服务未配置”。
- `sys_user.username` 唯一，非空 `phone` 唯一，密码继续使用 BCrypt。

## 7. 学生端链路

### 7.1 真实接口

| 方法 | 路径 | 功能 |
| --- | --- | --- |
| GET | `/api/v1/student/home` | 学生首页聚合数据 |
| GET | `/api/v1/case-market/list` | 公开病例列表 |
| GET | `/api/v1/case-market/{id}` | 公开病例详情 |
| GET | `/api/v1/student/daily-cases/today` | 今日病例完整题目 |
| POST | `/api/v1/student/daily-cases/submit` | 提交今日病例答案 |
| GET | `/api/v1/student/mistakes` | 错题列表 |
| GET | `/api/v1/student/activity` | 训练热力图和统计 |
| GET | `/api/v1/student/assignments/my` | 我的作业 |
| GET | `/api/v1/student/assignments/{id}` | 作业详情 |
| POST | `/api/v1/student/assignments/{id}/submit-record` | 提交大病历 |
| GET | `/api/v1/student/assignments/{id}/review` | 查询批阅状态和结果 |
| POST | `/api/v1/student/review-report/export` | 生成复盘报告 |

公开病例接口不返回隐藏疾病、标准答案或标准问诊路径。每日一例增加题干、选项、标准答案、解析和教材出处；确定性答案由后端判定，LLM 只增强解释，因此没有模型密钥时仍能正确判题。

### 7.2 问诊 SSE

1. Flutter 请求 Spring Boot 创建会话。
2. Spring Boot 校验学生、病例和可选作业实例，返回 `sessionId`。
3. Flutter 携带 JWT 和 `sessionId` 请求 FastAPI SSE。
4. FastAPI 校验 JWT，并通过内部接口确认会话归属。
5. FastAPI 从 Spring Boot 获取真实病例上下文和历史消息。
6. FastAPI 流式返回 `message`、`tree`、`socrates`、`citation`、`safety`、`error` 和 `done` 事件。
7. 学生消息、患者回复、思维树和最终报告写入 Spring Boot/MySQL。
8. 断线后从已保存消息恢复；不自动重复发送上一条学生消息。

当前用客户端消息拼装病例上下文的占位逻辑将删除。FastAPI 接口不再匿名接受任意 `sessionId`。

### 7.3 AI 降级

- 模型配置完整时调用真实模型。
- 配置缺失时返回 `degraded: true` 和明确说明。
- 影像模型未配置时不假装完成读图。
- 降级批阅不能作为教师最终成绩。
- 格式规则、标准答案判题等确定性能力继续正常工作。
- 健康接口分别报告业务服务、数据库、Redis、Milvus 和模型配置状态。

### 7.4 学生作业状态

作业实例状态沿用：未开始、问诊中、格式打回、AI 批阅中、待复核、已完成。格式校验失败时允许修改重交；AI 失败时记录失败原因和重试次数，避免永久停留在“AI 批阅中”。

## 8. 教师端链路

### 8.1 教师首页与洞察

| 方法 | 路径 | 功能 |
| --- | --- | --- |
| GET | `/api/v1/teacher/home` | 当前教师首页聚合数据 |
| GET | `/api/v1/teacher/insights` | 授权班级的真实学情聚合 |

统计只覆盖本人作业和授权班级。没有记录时返回空数据，不生成随机指标。

### 8.2 病例

复用并完善现有教师病例 CRUD、预览、发布审核、病例广场列表与引用接口。Flutter 保存成功后使用后端 ID。病例引用创建独立副本，并保留 `source_case_id`。

### 8.3 班级和作业

| 方法 | 路径 | 功能 |
| --- | --- | --- |
| GET | `/api/v1/teacher/classes` | 当前教师授权班级 |
| GET | `/api/v1/teacher/assignments` | 教师作业列表 |
| POST | `/api/v1/teacher/assignments` | 创建作业和学生实例 |
| GET | `/api/v1/teacher/assignments/{id}` | 作业详情 |
| GET | `/api/v1/teacher/assignments/{id}/progress` | 进度和学生明细 |

创建作业必须校验病例归属和班级授权；为目标班级正常学生创建独立实例。

### 8.4 批阅

| 方法 | 路径 | 功能 |
| --- | --- | --- |
| GET | `/api/v1/teacher/reviews` | 当前教师待复核队列 |
| GET | `/api/v1/teacher/reviews/{instanceId}` | 学生病历与最新批阅 |
| POST | `/api/v1/teacher/reviews/{instanceId}/override` | 教师最终复核 |
| POST | `/api/v1/teacher/reviews/{instanceId}/retry-ai` | 重试失败的 AI 批阅 |

队列由现有表关联查询，不建立重复队列表。教师结果新增为 `TEACHER` 记录，保留 AI 原记录并写审计日志。

### 8.5 教师资质

继续使用 `/api/v1/teacher/profile/audit-submit`。未认证教师可以登录，但发布病例和正式布置作业按后端规则限制，并返回具体原因。

## 9. 数据库设计与迁移

继续使用现有核心表。新增最少四张表：

| 表 | 用途 |
| --- | --- |
| `teaching_class` | 班级基础信息 |
| `teacher_class_authorization` | 教师与授权班级关系 |
| `assignment_target_class` | 作业与目标班级关系 |
| `daily_case_submission` | 每日一例提交和判题结果 |

现有 `authorized_classes` JSON 暂时保留兼容旧数据，新逻辑以关系表为准。能够识别的旧数据由迁移脚本导入关系表。

数据库文件分工：

```text
deploy/mysql/init.sql                  全新空库完整初始化
backend/src/main/resources/db/migration/  Flyway 版本化迁移
deploy/mysql/seed/demo_data.sql        可选演示数据
```

- 当前 `data/mysql` 不删除、不重建。
- 在临时 MySQL 中验证空库初始化和迁移。
- 当前已有库使用 Flyway baseline 后执行增量迁移。
- 演示数据脚本可重复执行且不覆盖真实用户数据。
- SQL 不保存明文密码；演示密码使用与后端一致的 BCrypt 哈希。

## 10. 开源组件政策

选型同时检查维护活跃度、版本、许可证、安全记录和兼容性，Star 数不作为唯一标准。最终开发文档记录仓库、版本、许可证、用途、使用位置、替代方案和未采用原因。

拟采用：

- `sse-starlette`（BSD-3-Clause，https://github.com/sysid/sse-starlette）：FastAPI SSE 连接、心跳、断线和关闭。
- `PyJWT`（MIT，https://github.com/jpadilla/pyjwt）：FastAPI 校验 Spring Boot JWT。
- `Flyway`（Apache-2.0，https://github.com/flyway/flyway）：数据库版本迁移。
- `flutter_secure_storage`（BSD-3-Clause）：Flutter token 安全存储。
- 继续复用 Dio、Riverpod、GoRouter 和已有 `tenacity`。

不采用 FastAPI Users，因为用户和权限由 Spring Boot 统一管理；不采用完整第三方脚手架，避免形成第二套架构。

## 11. 错误、日志与安全

- Flutter 同时检查 HTTP 状态和业务 `code`，统一转为网络、超时、认证、权限、业务、契约、AI 未配置/降级和未知错误。
- 页面不展示 Java/Python 堆栈或数据库原始异常。
- 日志不得记录密码、完整 JWT、短信验证码（生产）、身份证或完整医疗文本。
- AI 内部接口继续使用 `X-Internal-Token`；Mobile 不能调用内部回调。
- 所有学生/教师接口在服务端校验资源归属，不能只依赖前端隐藏入口。
- 生产环境禁止弱 JWT 密钥、开发验证码返回和不安全 HTTP。

## 12. 测试与验收

### 12.1 自动测试

- Spring Boot：双登录、验证码频控、角色、token、病例权限、班级授权、作业实例、批阅归属、AI 回调和迁移。
- FastAPI：JWT、会话归属、真实上下文、SSE 事件、回调、降级、安全拦截和健康检查。
- Flutter：双登录、学生/教师路由、重启恢复、刷新失败、页面加载/空/错误/重试、SSE、提交、批阅和 Mock 隔离。

### 12.2 Docker 与真机

1. 在临时 MySQL 验证空库脚本。
2. 备份/只读核对现有库后执行增量迁移。
3. 重建 Backend 和 AI。
4. 验证 MySQL、Redis、Backend、AI 健康状态。
5. 运行真实 HTTP 冒烟测试。
6. 运行 Maven、pytest、Flutter analyze 和 Flutter test。
7. 构建 Debug APK。
8. 在模拟器或真机完成学生和教师主链路。
9. 关闭 AI/Backend 验证降级和错误状态，确认不显示伪 Mock 成功数据。

验收通过的最低标准：

- 两种登录方式可用，角色页面绝不串用。
- 核心学生和教师页面读取真实接口。
- 问诊上下文来自数据库，消息可恢复。
- 作业从创建、学生提交、AI 批阅到教师复核形成闭环。
- 配置缺失有明确说明，Mock/降级可识别。
- 当前数据库数据未被破坏。
- 自动测试和 Debug APK 构建通过。

## 13. 最终开发文档

新增 `docs/FLUTTER_MOBILE_FULLSTACK_GUIDE.md`，按新手可执行标准说明：

- 系统组成、目录和每个服务职责。
- Docker 启动、全新建库、已有库迁移、演示数据导入和验证。
- 所有环境变量、是否必填、留空效果和安全注意事项。
- 双登录、角色路由、每个页面的数据来源。
- 每个接口的方法、路径、权限、参数、返回、内部流程和 JSON 示例。
- Backend/FastAPI/SSE 互动、每张表用途和主要关系。
- 本次修改文件与修改原因。
- 已完成、明确保留 Mock、降级能力和未实现事项。
- 开源组件来源、版本、许可证和使用位置。
- 测试、真机连接、常见错误、排查命令和生产前检查清单。

## 14. 明确不实现项

- Vue Web 的真实接口改造。
- 手机号自动注册、找回密码和第三方社交登录。
- 在未选择短信厂商前的真实短信发送。
- 在未提供模型密钥前的真实 LLM/视觉模型结论。
- 独立 API 网关、消息队列、微服务治理和通用低代码后台。
- Mobile 管理员工作区。

这些内容会在最终开发文档中明确列出，不以 Mock 数据伪装为已完成。
