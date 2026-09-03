# 智愈寻真移动端真实接口联调设计

日期：2026-07-17
范围：`mobile/` Flutter 学生/教师端、现有 Spring Boot 接口联调、AI 容器健康恢复

## 1. 背景与目标

当前 Flutter 移动端已完成主要页面和双身份路由，但登录与业务页面全部直接读取 `MockData`。`Dio` 客户端虽已存在，却没有被 Repository 使用；`AppConfig.useMock` 也被硬编码为 `true`，没有形成运行时数据源切换。

本次改造采用分阶段真实联调：先打通登录、JWT、用户信息和与现有后端契约匹配的核心只读接口，同时保留暂无后端读取接口的页面数据为显式 Mock。真实模式下接口失败必须展示错误，不允许静默回退 Mock，以免产生“页面有数据但实际没有联通”的假象。

## 2. 范围

### 2.1 本期接入真实接口

| 移动端能力 | 方法与路径 | 身份 |
| --- | --- | --- |
| 登录 | `POST /api/v1/auth/login` | 学生、教师 |
| 当前用户 | `GET /api/v1/auth/me` | 学生、教师 |
| 病例广场 | `GET /api/v1/case-market/list` | 学生、教师 |
| 今日病例 | `GET /api/v1/student/daily-cases/today` | 学生 |
| 我的作业 | `GET /api/v1/student/assignments/my` | 学生 |
| 错题列表 | `GET /api/v1/student/mistakes` | 学生 |
| 教师病例 | `GET /api/v1/teacher/cases` | 教师 |

### 2.2 本期保留 Mock

- 学生问诊聊天、思维树和 AI 增量输出。
- 学生能力雷达、学习路径和训练热力图。
- 教师作业列表，因为后端只有创建作业和按 ID 查询进度，没有教师作业列表接口。
- 教师批阅队列，因为后端只有按实例 ID 查询批阅详情，没有队列列表接口。
- 班级薄弱点和格式盾牌规则，因为目前没有对应的前端读取接口。
- 病例详情中后端列表契约未提供的主诉、查体要求、禁忌检查、预计时长等字段。

保留 Mock 的模块必须在代码结构上与真实模块隔离，后续新增后端接口时可以逐项替换，不把 Mock 字段伪装成后端返回值。

### 2.3 不在本期范围

- 新增或修改 Spring Boot 业务接口。
- 接入 AI 问诊、影像分析和 SSE 流。
- 实现教师病例创建、作业创建、错题提交、病例引用等写操作。
- 管理员角色的移动端登录；后端按设计拒绝 `role >= 2` 的 App 登录。
- 修改现有视觉系统或重新设计页面布局。

## 3. 方案选择

采用混合 Repository 方案。页面只依赖 Repository 和 Riverpod Provider，不直接依赖 `Dio`。Repository 根据编译期配置选择远程数据源或 Mock 数据源。

未采用页面直接调用 `Dio`，因为这会让鉴权、错误处理和响应解析散落在多个页面。未采用 OpenAPI 全量生成客户端，因为当前移动端展示模型与后端 VO 存在较大差异，首期生成的类型仍需要额外适配，不能降低本期风险。

## 4. 配置与运行模式

`AppConfig` 增加以下编译期配置：

```dart
static const bool useMock = bool.fromEnvironment(
  'USE_MOCK',
  defaultValue: true,
);

static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
```

模式规则：

- 未传 `USE_MOCK` 时继续使用 Mock，保证现有演示和 Widget 测试不依赖后端。
- `USE_MOCK=false` 时，已接入模块只访问真实接口；失败后显示错误，不回退 Mock。
- 暂未接入的模块继续由专门的 Mock Repository 提供数据，不受网络异常影响。

真机开发推荐使用 ADB reverse：

```powershell
E:\Android_sdk\platform-tools\adb.exe -s adb-AQWPUT4513019475-huFWws._adb-tls-connect._tcp reverse tcp:8080 tcp:8080
```

启动参数：

```powershell
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat run `
  -d adb-AQWPUT4513019475-huFWws._adb-tls-connect._tcp `
  --dart-define=USE_MOCK=false `
  --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

局域网备选地址为 `http://192.168.1.114:8080`，但需要手机和电脑处于同一网络，并允许 Windows 防火墙的 8080 入站访问。

## 5. 组件边界

### 5.1 配置层

`AppConfig` 只负责读取编译期配置和定义非敏感键名，不持有运行态对象。应用启动时将这些常量转换为可注入的 `AppEnvironment`，Repository 依赖 `AppEnvironment` 而不是直接读取静态常量；测试可以分别注入 Mock 和 Remote 环境，不需要依赖测试进程的编译参数。

### 5.2 会话存储

新增 `TokenStore` 接口，生产实现使用 `flutter_secure_storage` 保存访问令牌和刷新令牌。`SharedPreferences` 继续保存非敏感的 `username`、`role`、`userId`、`displayName` 等轻量会话快照，以支持应用启动时同步恢复路由。

测试使用内存版 `TokenStore`，不访问 Android Keystore 或 iOS Keychain。

### 5.3 HTTP 客户端

统一的 `Dio` 实例负责：

- 使用 `AppConfig.apiBaseUrl`。
- 设置连接和响应超时。
- 请求前从 `TokenStore` 读取 token，并添加 `Authorization: Bearer <token>`。
- 保持 JSON Content-Type。
- 输出仅限 debug 模式的请求方法、路径、耗时和业务码，不记录密码、token 或完整医疗数据。

### 5.4 响应边界

后端统一响应：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

新增统一响应解析器：

- HTTP 非 2xx：转换为 `ApiException`。
- HTTP 2xx 且 `code != 0`：仍转换为 `ApiException`。
- `code == 0`：将 `data` 交给具体 DTO 解析。
- `data` 缺失或类型错误：作为响应契约错误处理，不强制转换为假数据。
- `code == 1001` 或 `1002`：清除本地会话并通知登录状态失效。

### 5.5 远程数据源

按业务边界拆分为：

- `AuthRemoteSource`：登录、当前用户。
- `StudentRemoteSource`：今日病例、我的作业、错题。
- `CaseRemoteSource`：病例广场、教师病例。

Remote Source 只负责 HTTP、DTO 解析和分页结构，不直接操作 Widget 状态。

### 5.6 Repository

- `AuthRepository` 负责会话持久化、登录态恢复、登出和远程/Mock 登录选择。
- `CaseRepository` 负责病例广场、今日病例和教师病例的数据源选择与展示模型映射。
- `StudentRepository` 负责学生作业和错题的数据源选择与展示模型映射。
- 现有 `LearningRepository` 与 `TeachingRepository` 中没有真实读取接口的能力继续显式使用 Mock。

Repository 方法统一返回 `Future<T>`。Mock 分支使用 `Future.value` 或短暂可控延时，保证页面的加载、错误和数据状态在两种模式下使用同一套接口。

## 6. 数据映射

远程 DTO 与现有 UI 模型分离。DTO 字段与 OpenAPI 契约一致，展示模型只承载页面确实需要的数据。

### 6.1 用户

- `userId` / `id` → `UserModel.id`
- `username` → `UserModel.username`
- `realName` → `UserModel.displayName`
- `role` → `UserModel.role`
- `avatar` → `UserModel.avatarUrl`
- `auditStatus` → 教师认证展示状态

### 6.2 病例广场

- `id`、`title`、`creatorName`、`department`
- `difficulty` 转换为稳定的中文难度标签
- `referenceCount`、`ratingAvg`
- `knowledgeTags` 按后端实际 JSON 或分隔格式容错解析

病例广场模型补充后端 ID，后续病例引用操作不再依赖标题定位。

### 6.3 今日病例与教师病例

列表页只展示接口实际提供的标题、科室、难度、状态、引用数和评分。后端未提供的详情字段不使用 Mock 补齐；进入尚未真实接入的详情页时，页面明确处于演示数据模式。

### 6.4 学生作业

新增与 `StudentAssignmentVO` 对齐的移动端展示模型，包含 `instanceId`、`assignmentId`、标题、病例 ID、病例标题、截止时间和状态。它不复用教师端现有的 `AssignmentModel`，避免把班级进度字段与学生作业字段混在一起。

### 6.5 错题

- `mistakeType` → 类型
- `caseTitle` → 标题
- `knowledgeTag` → 标签
- `evidenceJson` → 证据摘要；无法解析时显示原始文本的安全截断
- `resolvedStatus` → 是否已复盘

## 7. 页面状态

接入真实数据的页面使用 Riverpod `AsyncValue` 或等价的显式状态，必须覆盖：

- 首次加载。
- 成功且有数据。
- 成功但为空。
- 网络超时或无法连接。
- 后端业务错误。
- token 失效并返回登录页。
- 用户主动重试。

切换筛选或分页时保留当前内容，避免短暂白屏；首期分页只加载第一页，页面大小统一为 20，并保留后续加载更多的接口边界。

## 8. Android 网络配置

- 将 `android.permission.INTERNET` 放入 main Manifest，保证 release 包可访问网络。
- debug 构建允许访问本地 HTTP 地址，release 不默认允许明文 HTTP。
- 本地联调的明文放行仅存在于 debug 配置；生产环境必须使用 HTTPS。
- Android target SDK 36 下，不依赖系统对明文流量的隐式兼容。

## 9. 错误与日志语义

`ApiException` 至少包含：

- `code`：后端业务码或客户端归一化错误码。
- `message`：适合展示给用户的中文消息。
- `kind`：网络、超时、未认证、无权限、业务错误、契约错误、未知错误。
- `cause`：仅供 debug 诊断，不直接渲染。

后端当前很多业务错误使用 HTTP 200 返回，因此页面不得只依据 HTTP 状态判断成功。网络日志不得输出 JWT、refresh token、登录密码、完整病历或身份证件信息。

## 10. Docker 与服务恢复

Spring Boot、MySQL 和 Redis 当前健康，本期不修改后端代码，因此不重建 Spring Boot 镜像。

AI 容器镜像早于 `requirements.txt` 中 `pypdf` 依赖的更新，容器虽然显示 Running，但 Uvicorn 子进程因 `ModuleNotFoundError: pypdf` 未能提供服务。执行：

```powershell
docker compose build ai
docker compose up -d ai
```

重建后验证：

```powershell
curl http://127.0.0.1:8000/health
```

同时为 AI 服务增加 Compose healthcheck，使 `docker compose ps` 能区分“容器进程存在”和“FastAPI 应用健康”。此项只修改 Docker 健康探测，不改变 AI 业务接口。

## 11. 测试策略

所有生产代码改动遵循测试先行。

### 11.1 单元测试

- `AppEnvironment` 的 Mock/Remote 分流通过注入不同配置对象测试；`AppConfig` 只保留最小编译参数冒烟验证。
- 响应解析器覆盖成功、业务错误、空 data、错误 data 类型。
- DTO 覆盖真实 OpenAPI 示例与缺失可选字段。
- `AuthRepository` 覆盖真实登录持久化、Mock 登录、登出和会话恢复。
- token 拦截器覆盖有 token、无 token 和敏感信息不进入日志。
- Repository 覆盖 Mock/Remote 的明确分流，确认真实失败不会回退 Mock。

### 11.2 Widget 测试

- 登录成功按真实 role 进入正确工作区。
- 登录业务错误显示后端消息。
- 学生与教师核心列表覆盖加载、空、错误、重试和成功状态。
- 现有 Mock 默认模式页面测试继续通过。

### 11.3 集成与真机验证

- `flutter analyze` 无错误。
- 完整 `flutter test` 通过。
- Debug APK 构建成功。
- 手机通过 ADB reverse 请求 Spring Boot 健康接口。
- 手机使用 `student01 / 123456` 和 `teacher01 / 123456` 完成真实登录。
- 登录后后端日志出现对应接口请求，移动端保存的 token 不以 `mock-` 开头。
- 关闭 Spring Boot 后，真实模式页面显示连接错误而不是 Mock 数据。
- AI 容器重建后 `/health` 返回成功，Compose 显示健康。

## 12. 验收标准

1. 默认构建仍可在无后端环境下使用 Mock 浏览现有页面。
2. `USE_MOCK=false` 时登录调用真实 `/api/v1/auth/login`。
3. JWT 被安全保存并自动加入后续请求。
4. 学生和教师按后端 role 正确分流，管理角色仍被拒绝进入 App。
5. 本期七类真实能力能在手机上获取 Docker 后端数据。
6. 真实接口失败时出现清晰错误和重试入口，不展示伪造成功数据。
7. 暂无接口的模块仍可使用 Mock，且界面或代码边界能明确识别其演示属性。
8. Spring Boot 无需重建；AI 镜像重建后健康检查通过。
9. `flutter analyze`、完整测试和 Debug APK 构建全部通过。
