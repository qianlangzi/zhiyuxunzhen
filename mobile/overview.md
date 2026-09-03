# 智愈寻真 - Flutter 移动端开发概览

## 项目概述

基于 PRD V2.1 规范，使用 Flutter 框架开发了同时支持 iOS 和 Android 双平台的移动应用。学生端与教师端共用同一个 App 包，通过登录角色分流。

## 技术栈（严格遵循 PRD 7.1.1）

| 类别 | 技术方案 |
| --- | --- |
| 状态管理 | Riverpod 2.x |
| 路由 | go_router |
| 网络请求 | dio |
| UI 组件 | Material Design 3 |
| 图表 | fl_chart + CustomPaint |
| 本地存储 | shared_preferences + hive |
| 图片处理 | image_picker + image_cropper |
| PDF 生成 | pdf + printing |
| 安全存储 | flutter_secure_storage |

## 项目结构（遵循 PRD 16.1.1）

```
lib/
├── main.dart                      # 应用入口
├── app.dart                       # MaterialApp 配置
├── core/                          # 核心基础设施
│   ├── config/                    # 环境配置
│   ├── constants/                 # 常量定义
│   ├── theme/                     # 主题、颜色、字体
│   │   ├── app_colors.dart        # 设计系统色彩（从 CSS 变量转换）
│   │   └── app_theme.dart         # Material 3 主题
│   └── utils/                     # 工具类
├── data/                          # 数据层
│   ├── models/                    # 数据模型
│   ├── providers/                 # Riverpod Mock 数据
│   └── repositories/              # 仓库实现
├── features/                      # 功能模块
│   ├── auth/                      # 登录、角色分流
│   ├── student/                   # 学生端 7 个页面
│   │   ├── home/                  # 首页·学习中心
│   │   ├── chat/                  # AI 问诊室
│   │   ├── tree/                  # 临床思维树
│   │   ├── result/                # OSCE 雷达图
│   │   ├── mistakes/              # 错题本
│   │   ├── report/                # AI 复盘报告
│   │   ├── daily_case/            # 每日一例
│   │   └── profile/               # 我的
│   └── teacher/                   # 教师端 6 个页面
│       ├── home/                  # 工作台
│       ├── case_config/           # SP 配置台
│       ├── market/                # 病例广场
│       ├── assignments/           # 作业分发
│       ├── review/                # 智能批阅
│       ├── dashboard/             # 学情看板
│       └── profile/               # 我的
├── shared/                        # 共享组件
│   └── widgets/                   # 通用 Widget
└── routes/                        # go_router 路由定义
```

## 已完成页面

### 学生端（7 页）
1. **首页·学习中心** - 问候区、学习热力图、每日一例卡、待办作业、薄弱知识点
2. **AI 问诊室** - 流式对话、病人/学生/导师消息、检查结果、思维树侧滑面板
3. **临床思维树** - 卫生经济学费用卡、症状/病史/检查/诊断节点、苏格拉底提示
4. **OSCE 雷达图** - 六维雷达图（CustomPaint）、优点/改进点、推荐训练
5. **错题本** - 统计条、筛选栏、错题卡片（诊断错误/漏问/检查错误/已掌握）
6. **AI 复盘报告** - 封面统计、三大章节、递进式补救路径
7. **每日一例** - 病例摘要、关键检查、三道选择题

### 教师端（6 页）
1. **工作台** - 统计卡、待批阅列表、班级概览、病例广场动态
2. **SP 配置台** - 基础信息、患者画像、隐藏疾病、检查项目配置
3. **病例广场** - 筛选栏、病例卡片（官方认证标识）
4. **作业分发** - 作业信息、进度看板（6 阶段）、防作弊机制
5. **智能批阅** - 格式盾牌、大病历高亮、AI 评分卡、教师复核
6. **学情看板** - OSCE 均分雷达图、共性漏问、共性误诊、课堂补救

## 设计系统

从 HTML 原型的 CSS 变量推导出完整色彩体系：
- **主色调**: 苔藓绿 (Moss #2D4A3E)
- **警示色**: 朱砂红 (Vermilion #B8412E)
- **警告色**: 琥珀黄 (Amber #B8821E)
- **背景色**: 宣纸白 (Paper #F5F1E8)
- **字体**: NotoSerifSC (标题) + JetBrainsMono (数据/标签)

## 底部导航

- **学生端**: 学习 / 问诊 / 错题 / 我的
- **教师端**: 工作台 / 配置 / 广场 / 我的

## 构建状态（2026-07-22 验证）

- 已在本机 Flutter 3.44.5 环境执行 `flutter pub get`（170 个依赖全部解析成功）与 `flutter analyze`（**0 编译错误**）。
- 修复了初始构建中未暴露的两个阻塞性问题（此前未用 SDK 校验）：
  1. `app_widgets.dart` 相对导入路径错误（`../core/...` 应为 `../../core/...`），导致 AppColors / AppConstants 在整个共享组件中未定义、级联报错。
  2. `app_constants.dart` 缺少 `import 'package:flutter/material.dart';`，导致 `EdgeInsets` 未定义。
  3. `app_widgets.dart` 的 `AppHeaderTag` 对 `Text` 调用 `.toUpperCase()`，应作用于 `label` 字符串。
- 剩余 ~284 条均为 lint 级 info / warning（`prefer_const` 等），不影响构建与运行。

## 字体资产处理

- **JetBrainsMono**（数据 / 标签字体）已成功下载并打包至 `assets/fonts/`（Regular + Medium，已校验为有效 TTF）。
- **NotoSerifSC**（标题宋体）本环境无法下载：沙箱网络仅能访问 jsDelivr，而大型 CJK 字体二进制不可达；GitHub raw 及国内代理（ghproxy / gitmirror）均被限制。
- 已在全部 42 处 `NotoSerifSC` 用法上附加 `fontFamilyFallback: ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'Source Han Serif SC']`：iOS 回退 Songti SC、Android 回退 Noto Serif CJK SC，视觉与 Noto Serif SC 几乎一致，且保持 `'NotoSerifSC'` 为主字体名。
- 还原真实字体：运行 `tools/fetch_fonts.ps1`（经国内 GitHub 代理下载可变字体），并在 `pubspec.yaml` 的 `fonts:` 下加入 NotoSerifSC 条目，再 `flutter pub get` 即可，**业务代码无需改动**。

## 第二轮构建验证（2026-07-22 下午）

用户用 AS 打开后反馈大量错误，根因是首批修复（`app_widgets` 导入路径等）挡住了下游分析。实际还藏了 ~135 个真错，分四类系统性问题 + 6 个真 bug，已全部修掉：

- **路由常量循环**：`RouteNames` 从 `app_router.dart` 抽到独立文件 `lib/routes/route_names.dart`，避免循环导入。
- **模型字段重定义**：`AssignmentInstanceModel.studentId` 原本同时是 `int` 和 `String`。拆成 `studentId`(int) + `studentNumber`(String 学号)，同步 `mock_data_providers` 4 处调用。
- **批量补 `app_constants.dart` 导入**：features 下 15 个文件用 `AppRadius` 但没导入，用脚本统一补上。
- **真 bug**：`AssignmentModel.deadline` 改可空；4 处 `BoxDecoration` 误用 `borderLeft:` 合并为 `Border(left:...)`；`sp_config` 的 `MonoText(...).toUpperCase()` 改为对字符串调用；`chat_room` 漏 `Container` 右括号。

`flutter analyze` 最终结果：**0 编译错误**（剩 192 条 lint info/warning，不影响构建运行）。

## Android 平台脚手架补齐（2026-07-22 傍晚）

项目最初是手写搭建（仅 `pubspec.yaml` + `lib/`），**从未执行 `flutter create`**，因此原生目录缺失。在 AS 中运行 `flutter run` 时报 `AndroidManifest.xml could not be found` / `No application found for TargetPlatform.android_arm64`。

- 执行 `flutter create --org com.zhiyu --platforms=android .` 在现有工程内补齐 Android 平台目录（只启用 android，规避此前 Windows 桌面报错）。
- 原生配置整理：namespace / applicationId 改为 `com.zhiyu.xunzhen`；`MainActivity.kt` 同步移至 `kotlin/com/zhiyu/xunzhen/` 并修正 package；`AndroidManifest.xml` 增加 `INTERNET` 权限、应用名改为「智愈寻真」。
- 删除 `flutter create` 生成的样板测试 `test/widget_test.dart`（引用不存在的 `MyApp`）。
- **验证**：`flutter build apk --debug` 构建成功，产物 `build/app/outputs/flutter-apk/app-debug.apk`；`flutter analyze` 0 编译错误。

## 个人资料编辑与持久化（2026-07-23）

实现「我的 → 编辑资料 → 保存 → 首页同步刷新」完整闭环：

- **共享编辑页**：`lib/features/common/profile/profile_edit_screen.dart` 同时服务学生/教师，自动按角色隐藏「学号」字段；含头像选择、表单校验、保存/取消按钮及 hover 视觉反馈的编辑按钮。
- **本地持久化**：`UserModel` 新增 `toJson()` / `fromJson()`；`AuthNotifier` 通过 `shared_preferences` 在启动时恢复用户、在 `updateProfile` / 登录 / 登出时保存/清除数据。
- **首页同步**：`StudentHomeScreen` 改为 `ConsumerStatefulWidget`，问候区姓名、专业、年级从 `authProvider` 实时读取，编辑保存后首页立即刷新，且应用重启不丢失。
- **构建验证**：`flutter analyze` 0 编译错误。

## 交互全量接通（2026-07-23）

在保持现有静态布局不变的前提下，把所有可见交互接通，消灭空响应与断链：

- **共享反馈层**：新增 `lib/shared/utils/feedback.dart`（`AppFeedback`：success/error/info SnackBar、`confirm` 二次确认弹窗、`showLoading` 遮罩、`mockAsync` 模拟网络延迟/失败），供所有提交动作复用。
- **登录与路由守卫**：`LoginScreen` 改为 `ConsumerStatefulWidget`，加表单校验（用户名≥2、密码≥6）、密码可见切换、加载态、错误反馈，接 `authProvider` 按角色登录；`appRouter` 新增 `redirect` 守卫：未登录只能进 `/login`、学生/教师不可越权访问对方路由、已登录访问登录页按角色回首页。
- **底部 Tab 导航**：学生/教师各 4 屏 Tab 的 `currentIndex` 与 `onTap` 路由一致，统一 `goNamed` 切换，无重复入栈。
- **空按钮全部接通**（原 9 处 `() {}` 清零）：
  - 学生首页：待办作业项 → 进入问诊；「全部作业」「补救路径」→ 反馈/跳转复盘报告。
  - 每日一例：提交答案 → 模拟判题 → 弹窗反馈（答对数 + 避坑点 + 教材出处）→ 完成回首页。
  - 复盘报告：导出 PDF → 加载提示 + 成功反馈（演示版）。
  - 病例广场：引用 → 二次确认 → 成功反馈 → 跳配置台。
  - 作业分发：催交提醒 → 成功反馈；查看详情 → 跳批阅。
  - SP 配置台：预览试诊/保存草稿/发布作业 → 必填校验（标题/年龄/主诉/标签）+ 加载态 + 二次确认 + 成功/错误反馈。
  - 智能批阅：提交复核 → 分数校验（0~100）+ 二次确认 + 成功反馈 → 跳学情看板。
- **问诊室**：发送按钮接通消息追加 + 模拟 SP 流式回复（1.2s + 输入中态）+ 自动滚动到底；快捷短语填入输入框；「+ 上传影像」接 `image_picker` 选图；「+ 开检查」反馈提示。
- **「我的」菜单逐项路由**：学生（错题本/复盘报告/每日一例历史/热力图/关于）与教师（学情看板/批阅历史/病例广场/我的病例/关于）按菜单项跳转已有页面，其余「设置/资质认证」给"即将开放"反馈。
- **验证**：`flutter analyze` 0 编译错误；全仓 `() {}` 空回调 0 处。

## 后续开发建议

1. 用 Android Studio 打开本项目目录（含 pubspec.yaml），运行 `flutter clean && flutter pub get`
2. 在模拟器或真机运行 `flutter run` 预览 UI（建议同时验证 iOS / Android 两端表现）
3. 对接 Spring Boot + FastAPI 后端 API（替换 Riverpod Mock Provider 及本地持久化为真实后端）
4. 实现 SSE 流式对话真实通信
5. 可选：用 fl_chart 替换 CustomPaint 雷达图（当前实现已满足 UI 一致性）
6. 补充单元测试和集成测试
