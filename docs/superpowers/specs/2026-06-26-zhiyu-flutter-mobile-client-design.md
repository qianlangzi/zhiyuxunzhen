# 智愈寻真 Flutter 移动客户端重构设计

日期：2026-06-26
范围：从 0 新建学生/教师共用 Flutter App，保留 Vue 3 Web 管理端
基准文档：`docs/PRD_V1.0.md`

## 1. 设计读法

本次重构将学生端和教师端从现有 Vue 演示页面中剥离，改为独立 Flutter 移动客户端。学生与教师共用一个 App 包，登录后按 JWT 中的 `role` 分流；管理端继续由 Vue 3 Web 承载，App 不开放管理类功能。

视觉方向保留现有“临床玻璃舱”语言：冷白背景、深墨绿文本、玉青品牌色、医疗青强调色、克制的卡片和状态反馈。Logo 沿用 `front/src/assets/brand-logo.png`，不重绘、不改比例、不改色。

## 2. 工程边界

新增目录：

- `mobile/`：Flutter 客户端源码。

保留不动：

- `front/admin/`
- `front/src/admin/`
- `front/vite.admin.config.ts`

备份旧代码：

- 将现有 Vue 学生/教师端和共享壳层备份到 `front/legacy-student-teacher-<timestamp>/`。

当前环境限制：

- 本机暂未安装 Flutter / Dart CLI，因此本轮可交付源码骨架和实现文件，但不能执行 `flutter create`、`flutter analyze`、`flutter build`。
- 原生 Android/iOS 工程目录需要在安装 Flutter SDK 后通过 `flutter create .` 或等价命令生成。

## 3. 技术栈

- Flutter Material 3
- flutter_riverpod：全局状态与异步状态
- go_router：声明式路由和角色守卫
- dio：HTTP、拦截器、后续 SSE/文件上传基础
- shared_preferences：开发期轻量登录态持久化
- fl_chart：后续 OSCE 雷达图和学情图表
- image_picker：后续影像上传

## 4. 信息架构

### 4.1 登录与角色分流

- 登录页提供学生和教师两种快速演示身份。
- 登录成功后写入 token、username、role。
- role=0：进入学生 Shell。
- role=1：进入教师 Shell。
- role>=2：App 端提示“请使用 Web 管理端”，不进入移动端功能。

### 4.2 学生端

底部 Tab：

- 首页：今日训练、连续练习、下一步建议。
- 病例：病例列表、难度、知识点、进入问诊。
- 问诊：模拟病人对话、检查成本、思维节点、苏格拉底提示。
- 反馈：OSCE 四维、错题、学习路径。
- 我的：账号、学习统计、医学免责声明。

### 4.3 教师端

底部 Tab：

- 概览：待复核、完成率、班级薄弱点。
- 病例：SP 配置、病例广场入口、草稿。
- 作业：作业列表、提交进度、格式盾牌状态。
- 批阅：AI 批阅队列、人工复核、争议项。
- 我的：资质状态、服务健康、账号。

## 5. 移动 UX 规则

- 使用手机原生习惯：顶部 AppBar + 内容滚动 + 底部 NavigationBar。
- 所有主触控目标不小于 44px。
- 固定底部导航尊重 SafeArea。
- 表单使用可读标签，不用 placeholder 代替 label。
- 卡片只承载真实信息分组，不做过多装饰。
- 动效只用于页面切换、按压反馈、状态变化，避免长时间循环动画。
- 主要页面先支持 mock 数据，后续用 Repository 替换真实接口。

## 6. 目录设计

```
mobile/
├── pubspec.yaml
├── README.md
└── lib/
    ├── main.dart
    ├── app.dart
    ├── core/
    │   ├── config/
    │   ├── constants/
    │   ├── theme/
    │   └── utils/
    ├── data/
    │   ├── models/
    │   ├── repositories/
    │   └── sources/
    ├── features/
    │   ├── auth/
    │   ├── student/
    │   └── teacher/
    ├── routes/
    └── shared/
        └── widgets/
```

## 7. 验收标准

- `mobile/` 具备完整 Flutter App 源码骨架。
- App 启动入口、主题、路由、角色分流状态完整。
- 学生/教师页面能用 mock 数据表达 PRD 核心链路。
- 管理端 Vue 代码未被改动。
- 旧 Vue 学生/教师端代码已备份。
- 明确记录 Flutter SDK 未安装导致的未执行校验项。
