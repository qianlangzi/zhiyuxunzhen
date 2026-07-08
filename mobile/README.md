# 智愈寻真 · 移动客户端（Flutter）

学生 / 教师共用的内科学训练 App，配套 `front/admin` Vue 3 Web 管理端使用。
设计依据：`docs/superpowers/specs/2026-06-26-zhiyu-flutter-mobile-client-design.md`。

## 角色分流

| role | 端 | 进入方式 |
|------|----|----------|
| 0 学生 | 移动 App | 登录页选「学生端」→ `student01 / 123456` |
| 1 教师 | 移动 App | 登录页选「教师端」→ `teacher01 / 123456` |
| ≥2 管理 | Web 管理端 | App 拒绝进入，提示使用 Web 端 |

登录态写入 `SharedPreferences`，由 `go_router` 的 `redirect` 守卫控制访问。
学生越权访问 `/teacher/*`、教师越权访问 `/student/*` 时自动回到首页。

## 目录结构

```
mobile/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── assets/images/brand-logo.png        # 沿用品牌 logo
└── lib/
    ├── main.dart                       # 入口 + ProviderScope.overrides
    ├── app.dart                        # MaterialApp.router
    ├── core/
    │   ├── config/app_config.dart      # API 基址、mock 开关、storage key
    │   ├── constants/
    │   │   ├── app_colors.dart         # 临床玻璃舱配色（对齐 CSS 变量）
    │   │   ├── app_dimens.dart         # 间距 / 圆角 / 触控目标
    │   │   └── app_text_styles.dart    # 字号 / 字重
    │   ├── theme/app_theme.dart        # Material 3 主题
    │   └── utils/formatters.dart
    ├── data/
    │   ├── models/                     # user/case/chat/assignment/learning
    │   ├── repositories/
    │   │   ├── auth_repository.dart    # 登录 + SharedPreferences 持久化
    │   │   └── content_repository.dart # case/learning/teaching 仓库
    │   └── sources/
    │       ├── mock_data.dart          # 对齐 front/legacy mockData.ts
    │       └── api_client.dart         # dio Provider（接入后启用）
    ├── features/
    │   ├── auth/
    │   │   ├── auth_controller.dart    # Riverpod StateNotifier
    │   │   └── login_page.dart         # 角色切换 + 表单
    │   ├── student/
    │   │   ├── student_shell.dart      # 底部 5 Tab
    │   │   ├── home/student_home_page.dart
    │   │   ├── cases/cases_list_page.dart
    │   │   ├── cases/case_detail_page.dart
    │   │   ├── chat/chat_room_page.dart
    │   │   ├── feedback/feedback_page.dart
    │   │   ├── feedback/mistakes_page.dart
    │   │   └── profile/student_profile_page.dart
    │   └── teacher/
    │       ├── teacher_shell.dart      # 底部 5 Tab
    │       ├── overview/teacher_overview_page.dart
    │       ├── cases/case_config_page.dart
    │       ├── cases/case_market_page.dart
    │       ├── assignments/assignments_page.dart
    │       ├── review/review_page.dart
    │       └── profile/teacher_profile_page.dart
    ├── routes/app_router.dart          # go_router + 角色守卫 + ShellRoute
    └── shared/widgets/                 # ZyCard/Chip/AppBar/BottomBar 等
```

## 视觉规范

- 品牌色 `#0F766E` 玉青，强调色 `#14B8A6` 医疗青
- 文本 `#10231F` 深墨绿，背景 `#F4F8F7` 冷白
- 卡片：白底 + 1px 玻璃舱描边 + 柔和阴影
- 问诊室使用 `#071B22` 深色面板，气泡分学生 / SP / 导师三色
- 主触控目标 ≥ 44px，底部导航尊重 SafeArea
- 文本使用 PingFang / SF Pro / 微软雅黑 系统回退，未引入字体文件

## 移动 UX 要点

- 登录页：单一身份切换 + 表单 + 演示账号提示，移动端不再做分栏布局
- 学生首页：每日一例高亮卡 + 学习热力图 + 最近病例入口
- 病例列表：纵向单列卡片 + 横向科室筛选
- 问诊室：竖向聊天气泡 + 右上角按钮切换「思维路径」抽屉
- 教师批阅：列表卡片化，AI 评分按分数显色
- 所有 Tab 切换、按钮按压、状态变化使用 200ms 内的缩放 / 淡入动画

## 演示账号

| 角色 | 用户名 | 密码 |
|------|--------|------|
| 教师 | teacher01 | 123456 |
| 学生 | student01 | 123456 |

`AppConfig.useMock = true` 时使用本地 mock 校验，不调用后端。

## 后端联调

1. 在 `core/config/app_config.dart` 修改 `apiBaseUrl`：
   - Android 模拟器：`http://10.0.2.2:8080`
   - iOS 模拟器 / Web：`http://localhost:8080`
   - 真机：电脑局域网 IP `http://192.168.x.x:8080`
2. 把 `useMock` 改为 `false`
3. 在 `auth_repository.dart` 切换为 `dio.post('/v1/user/login', ...)`
4. 在 `content_repository.dart` 切换为各仓库对应的 dio 调用

## 工程化与原生工程

当前环境 **未安装 Flutter / Dart CLI**，因此：

- 已交付 `pubspec.yaml` / `lib/` 完整源码骨架
- **未执行** `flutter create .`，因此 `android/`、`ios/`、`web/`、`test/` 等原生工程目录尚未生成
- **未执行** `flutter pub get`、`flutter analyze`、`flutter build`

安装 Flutter SDK 后，在 `mobile/` 目录执行：

```bash
# 1. 生成原生工程（保留现有 pubspec.yaml 与 lib/）
flutter create --org com.zhiyu --project-name zhiyu .

# 2. 拉取依赖
flutter pub get

# 3. 静态检查
flutter analyze

# 4. 运行
flutter run
```

如果 `flutter create .` 检测到 `pubspec.yaml` 已存在，会询问是否覆盖，选择保留即可。
若它仍尝试覆盖 `pubspec.yaml`，可先备份再恢复：

```bash
cp pubspec.yaml pubspec.yaml.bak
flutter create --org com.zhiyu --project-name zhiyu .
mv pubspec.yaml.bak pubspec.yaml
flutter pub get
```

## 已知未执行校验项

| 项 | 原因 | 后续动作 |
|----|------|----------|
| `flutter analyze` | 本机无 Flutter SDK | 安装 SDK 后执行，修正 lint |
| `flutter test` | 无 `test/` 目录 | 安装 SDK 后补充 widget 测试 |
| 原生工程生成 | 同上 | `flutter create .` |
| 真机 UI 走查 | 同上 | iOS Simulator / Android Emulator 验证 |
| `fl_chart` 雷达图 | 当前用进度条表达四维 | 后续接入 fl_chart 替换 |
| `image_picker` 影像上传 | 暂未启用 | 影像判读页接入时启用 |
| 模型代码生成（json_serializable / riverpod_generator） | 已声明 dev 依赖但未跑 build_runner | 接入真实接口前执行 `dart run build_runner build` |

## 旧代码备份

Vue 旧学生 / 教师端代码已备份至 `front/legacy-student-teacher-20260626211852/`，
后续如需继续维护 Web 端页面，可基于该备份分支开发。
