# 知语寻真 Flutter 用户端重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留现有 Flutter 业务骨架、身份守卫、Repository 和 Logo 的前提下，把学生与教师共用的移动客户端重构为中文原生、临床极简、圆角舒适、动效克制且全流程可验证的用户端。

**Architecture:** 继续使用 Riverpod、go_router、Repository 和现有模型分层；先收敛主题、动效与共享组件，再依次迁移登录、学生流程和教师流程。页面只组合领域数据和共享视觉原语，三个月训练热力图作为独立可测试组件放入学生“我的”页面，批阅详情使用可拖动底部层，不引入新的状态管理或设计系统依赖。

**Tech Stack:** Flutter 3.44、Dart 3、Material 3、flutter_riverpod、go_router、shared_preferences、flutter_test。

---

## 0. 执行前提与当前基线

### 0.1 必读资料

- 设计规格：`docs/superpowers/specs/2026-07-15-zhiyu-mobile-user-redesign-design.md`
- Flutter 工程说明：`mobile/README.md`
- 路由入口：`mobile/lib/routes/app_router.dart`
- 当前主题：`mobile/lib/core/theme/app_theme.dart`
- 当前 mock 数据：`mobile/lib/data/sources/mock_data.dart`

### 0.2 已确认产品边界

- 只修改 `mobile/` Flutter 用户端。
- 学生和教师是同一个 App 的两种登录身份，不是两个独立端。
- 不设计、不修改 `front/`、`front/admin/` 或 `front/src/admin/`。
- 现有 Logo `mobile/assets/images/brand-logo.png` 必须原样使用。
- 手机竖屏优先，平板只做自然留白与最大宽度约束。
- 页面全部使用自然中文。

### 0.3 2026-07-15 基线命令

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat analyze
```

当前结果：`No issues found!`。

```powershell
cd E:\zhiyu\mobile
E:\flutter_windows_3.44.5\flutter\bin\flutter.bat test
```

当前结果：失败。唯一测试 `test/widget_test.dart` 的 `renders the login entry` 找不到文本“智愈寻真”。Task 1 必须先把测试入口修正为稳定基线，后续任务不得把此既有失败当成重构回归。

### 0.4 脏工作区纪律

当前仓库已有用户修改，并且同时存在已暂存和未暂存内容。执行期间必须遵守：

1. 不运行 `git reset --hard`、`git checkout --`、`git clean` 或批量回退命令。
2. 每次编辑前先执行 `git status --short` 和目标文件的 `git diff`。
3. 不使用 `git add -A`、`git add .`。
4. 提交时使用各任务末尾列出的 `git commit --only --` 精确路径，避免带入索引里已有的其他修改。
5. 若目标文件本身已有用户未提交修改，以当前工作树内容为基线继续修改，不恢复到 HEAD 版本。
6. 每个任务提交前对该任务“Files”小节列出的路径运行 `git diff --check --`。

## 1. 文件责任图

### 1.1 新建文件

| 文件 | 单一职责 |
| --- | --- |
| `mobile/lib/core/theme/app_motion.dart` | 统一动效时长、曲线，并响应系统“减少动态效果” |
| `mobile/lib/shared/widgets/zy_segmented_control.dart` | 登录身份、问诊模式和轻量筛选使用的分段控件 |
| `mobile/lib/shared/widgets/zy_skeleton.dart` | 与最终内容形状一致的骨架占位 |
| `mobile/lib/shared/widgets/zy_sticky_action_bar.dart` | 病例详情和表单底部固定操作区 |
| `mobile/lib/shared/widgets/zy_activity_heatmap.dart` | 最近三个月 13×7 小方块热力图、月份标签、语义和点击回调 |
| `mobile/lib/features/student/profile/training_activity.dart` | 91 天窗口归一化、训练天数、连续天数和完成次数计算 |
| `mobile/lib/features/teacher/review/review_detail_sheet.dart` | 可拖动批阅详情层与处理操作 |
| `mobile/test/helpers/test_harness.dart` | 统一主题、Provider、屏幕尺寸和登录态测试装配 |
| `mobile/test/core/theme/app_theme_test.dart` | 色彩、圆角、按钮、字体缩放与减少动效测试 |
| `mobile/test/shared/widgets/zy_bottom_bar_test.dart` | 底部导航选中态、点击和语义测试 |
| `mobile/test/shared/widgets/zy_activity_heatmap_test.dart` | 91 格、色阶、月份、点击和窄屏测试 |
| `mobile/test/features/auth/login_page_test.dart` | Logo、中文文案、身份切换、校验和提交状态测试 |
| `mobile/test/features/student/student_pages_test.dart` | 学生首页、病例、反馈、复盘和个人页结构测试 |
| `mobile/test/features/student/chat_room_page_test.dart` | 问诊模式、消息发送、滚动和键盘安全测试 |
| `mobile/test/features/teacher/teacher_pages_test.dart` | 教师概览、病例、作业、批阅和个人页结构测试 |
| `mobile/test/routes/role_routing_test.dart` | 单 App 双身份跳转和越权守卫测试 |
| `mobile/test/accessibility/responsive_smoke_test.dart` | 全部用户页在 360px 和字体放大下的溢出冒烟测试 |

### 1.2 主要修改文件

| 文件 | 修改责任 |
| --- | --- |
| `mobile/lib/app.dart` | 保留系统字体缩放、统一系统栏，不在应用层禁用可访问性 |
| `mobile/lib/core/constants/app_colors.dart` | 收敛为冷白、深青和业务状态色，移除页面依赖的装饰渐变与重阴影 |
| `mobile/lib/core/constants/app_dimens.dart` | 固化 8px 卡片、12px 控件、20px 浮层圆角和稳定间距 |
| `mobile/lib/core/constants/app_text_styles.dart` | 将页面标题降到 24–28px，减少普遍 900 字重 |
| `mobile/lib/core/theme/app_theme.dart` | 重做按钮、输入、底栏、弹层、焦点和触控反馈 |
| `mobile/lib/shared/widgets/widgets.dart` | 导出新增共享组件 |
| `mobile/lib/shared/widgets/zy_app_bar.dart` | 简化页面标题，移除默认大图标头像和 30px kicker |
| `mobile/lib/shared/widgets/zy_bottom_bar.dart` | 选中态改为小范围浅青指示，不使用整块深青胶囊 |
| `mobile/lib/shared/widgets/zy_card.dart` | 默认 8px 圆角、细边框、无阴影，只承载真实分组 |
| `mobile/lib/shared/widgets/zy_chip.dart` | 缩小圆角和内边距，区分状态标签与可交互筛选 |
| `mobile/lib/shared/widgets/zy_empty_state.dart` | 去掉大圆形插画，补充简洁错误/重试状态 |
| `mobile/lib/shared/widgets/zy_list_tile.dart` | 统一 44px 触控、分隔线与按压反馈 |
| `mobile/lib/data/models/learning_model.dart` | 为热力日补充完成次数和当天内容 |
| `mobile/lib/data/sources/mock_data.dart` | 生成真实最近 91 天日期及少量当天训练明细 |
| `mobile/lib/routes/app_router.dart` | 为全屏详情提供方向明确的推入/返回转场 |
| `mobile/lib/features/student/student_shell.dart` | 五入口导航与标签页轻量切换动画 |
| `mobile/lib/features/teacher/teacher_shell.dart` | 同一导航语言下的教师五入口与切换动画 |
| `mobile/lib/features/auth/login_page.dart` | 使用现有 Logo，统一登录按钮，中文身份选择和字段错误 |
| `mobile/lib/features/student/**` | 按训练优先级重组全部学生页面 |
| `mobile/lib/features/teacher/**` | 按教学待办优先级重组全部教师页面 |
| `mobile/test/widget_test.dart` | 保留为最小 App 冒烟测试，并修复当前失败 |

## Task 1: 建立稳定测试装配并修复基线失败

**Files:**
- Create: `mobile/test/helpers/test_harness.dart`
- Modify: `mobile/test/widget_test.dart`
- Test: `mobile/test/widget_test.dart`

- [ ] **Step 1: 记录现有状态并确认测试仍按基线失败**

Run:

```powershell
cd E:\zhiyu
git status --short
git diff -- mobile/test/widget_test.dart mobile/lib/app.dart mobile/lib/features/auth/login_page.dart
cd mobile
flutter test test/widget_test.dart --plain-name "renders the login entry"
```

Expected: FAIL，失败信息包含 `Found 0 widgets with text "智愈寻真"`。

- [ ] **Step 2: 新建统一测试装配**

Create `mobile/test/helpers/test_harness.dart` with this API:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiyu/app.dart';
import 'package:zhiyu/core/theme/app_theme.dart';
import 'package:zhiyu/data/repositories/auth_repository.dart';

const Size phone390 = Size(390, 844);
const Size phone360 = Size(360, 800);
const Size phone430 = Size(430, 932);

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = phone390,
  List<Override> overrides = const <Override>[],
  bool disableAnimations = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
          ),
          child: page,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpZhiyuApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const <String, Object>{},
  Size size = phone390,
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ZhiyuApp(),
    ),
  );
  await tester.pumpAndSettle();
}
```

- [ ] **Step 3: 将冒烟测试改成可诊断的登录入口测试**

Replace `mobile/test/widget_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/login_page.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('renders the login entry', (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());

    expect(find.text('知语寻真'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

Task 5 adds full-App persisted-session routing coverage. This smoke test intentionally isolates the login surface so route failures and visual failures remain distinguishable.

- [ ] **Step 4: 运行基线测试和静态分析**

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/widget_test.dart
flutter analyze
```

Expected: both commands exit 0; test reports `+1: All tests passed!` and analyze reports `No issues found!`。

- [ ] **Step 5: 提交测试基线**

```powershell
cd E:\zhiyu
git diff --check -- mobile/test/helpers/test_harness.dart mobile/test/widget_test.dart
git commit --only -- mobile/test/helpers/test_harness.dart mobile/test/widget_test.dart -m "test: stabilize mobile app harness"
```

## Task 2: 收敛设计令牌、主题、字体缩放与动效规则

**Files:**
- Create: `mobile/lib/core/theme/app_motion.dart`
- Create: `mobile/test/core/theme/app_theme_test.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/core/constants/app_colors.dart`
- Modify: `mobile/lib/core/constants/app_dimens.dart`
- Modify: `mobile/lib/core/constants/app_text_styles.dart`
- Modify: `mobile/lib/core/theme/app_theme.dart`

- [ ] **Step 1: 先写主题约束测试**

Create `mobile/test/core/theme/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/core/constants/app_colors.dart';
import 'package:zhiyu/core/constants/app_dimens.dart';
import 'package:zhiyu/core/theme/app_motion.dart';
import 'package:zhiyu/core/theme/app_theme.dart';

void main() {
  test('clinical minimal tokens stay constrained', () {
    expect(AppColors.bg, const Color(0xFFF7F9F9));
    expect(AppColors.brand, const Color(0xFF064B59));
    expect(AppDimens.radiusCard, 8);
    expect(AppDimens.radiusControl, 12);
    expect(AppDimens.radiusSheet, 20);
  });

  testWidgets('motion is disabled when the system requests it',
      (WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (BuildContext value) {
            context = value;
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(AppMotion.standard(context), Duration.zero);
  });

  test('buttons use comfortable non-pill corners', () {
    final ButtonStyle style = AppTheme.light.filledButtonTheme.style!;
    final OutlinedBorder shape = style.shape!.resolve(<WidgetState>{})!;
    expect((shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppDimens.radiusControl));
  });
}
```

- [ ] **Step 2: 运行测试确认缺少新令牌和动效类**

```powershell
cd E:\zhiyu\mobile
flutter test test/core/theme/app_theme_test.dart
```

Expected: FAIL，包含 `app_motion.dart` 不存在或 `radiusCard` 未定义。

- [ ] **Step 3: 定义稳定视觉令牌，保留迁移期兼容别名**

In `app_dimens.dart`, add the target constants and keep old names temporarily so pages can migrate task-by-task:

```dart
static const double radiusCard = 8;
static const double radiusControl = 12;
static const double radiusSheet = 20;
static const double radiusStatus = 6;

// Migration aliases; remove in Task 18 after all usages are gone.
static const double radiusSm = radiusCard;
static const double radiusMd = radiusControl;
static const double radiusLg = radiusControl;
static const double radiusXl = radiusSheet;
static const double radiusXxl = radiusSheet;
```

In `app_colors.dart`, make the palette explicit and remove page-facing gradient tokens:

```dart
static const Color bg = Color(0xFFF7F9F9);
static const Color surface = Color(0xFFFFFFFF);
static const Color ink = Color(0xFF161A1C);
static const Color muted = Color(0xFF596367);
static const Color soft = Color(0xFF7A8488);
static const Color line = Color(0xFFE3E8EA);
static const Color lineStrong = Color(0xFFC7D0D3);
static const Color brand = Color(0xFF064B59);
static const Color brandStrong = Color(0xFF003441);
static const Color brandSoft = Color(0xFFEAF1F2);
static const Color brandPressed = Color(0xFF002B35);
static const Color card = surface;
static const Color activity1 = Color(0xFFD8E7E9);
static const Color activity2 = Color(0xFFA9CDD2);
static const Color activity3 = Color(0xFF5F9CA5);
static const Color activity4 = brand;
```

Keep success/warning/danger tokens. Remove `bgGradientTop`, `deep`, `deepInk`, `deepMuted`, `shadow`, `shadowSoft`, and `shadowCard` only after `rg` confirms no page uses them in Task 18.

- [ ] **Step 4: 新建减少动态效果感知器**

Create `mobile/lib/core/theme/app_motion.dart`:

```dart
import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration standardDuration = Duration(milliseconds: 190);
  static const Duration routeDuration = Duration(milliseconds: 220);
  static const Curve standardCurve = Curves.easeOutCubic;

  static Duration fast(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : fastDuration;

  static Duration standard(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : standardDuration;

  static Duration route(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : routeDuration;
}
```

- [ ] **Step 5: 调整中文排版和 Material 主题**

Set the target text hierarchy in `app_text_styles.dart`:

```dart
static const TextStyle h1 = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
  height: 1.2,
);

static const TextStyle h2 = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
  height: 1.25,
);

static const TextStyle h3 = TextStyle(
  fontSize: 19,
  fontWeight: FontWeight.w600,
  color: AppColors.ink,
  height: 1.3,
);

static const TextStyle body = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w400,
  color: AppColors.ink,
  height: 1.6,
);
```

In `app_theme.dart`, make controls rounded but not pill-shaped:

```dart
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppDimens.radiusControl),
),
```

Apply that shape to filled and outlined buttons. Use `radiusControl` for inputs, `radiusSheet` for dialogs/bottom sheets, `AppColors.line` for dividers, and remove generic card shadows. Keep minimum control height at 48–50px and Material focus/semantics behavior.

- [ ] **Step 6: 恢复系统字体缩放**

In `mobile/lib/app.dart`, remove this override:

```dart
MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling)
```

Use the child directly:

```dart
builder: (BuildContext context, Widget? child) =>
    child ?? const SizedBox.shrink(),
```

Do not clamp text globally. Individual fixed controls must use flexible layout, wrapping, or a bounded local scale only if a test proves overflow.

- [ ] **Step 7: 运行主题测试、冒烟测试和分析**

```powershell
cd E:\zhiyu\mobile
flutter test test/core/theme/app_theme_test.dart test/widget_test.dart
flutter analyze
```

Expected: PASS；不得出现废弃 API、对比度相关常量错误或布局异常。

- [ ] **Step 8: 提交主题基础**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/app.dart mobile/lib/core/constants/app_colors.dart mobile/lib/core/constants/app_dimens.dart mobile/lib/core/constants/app_text_styles.dart mobile/lib/core/theme/app_motion.dart mobile/lib/core/theme/app_theme.dart mobile/test/core/theme/app_theme_test.dart
git commit --only -- mobile/lib/app.dart mobile/lib/core/constants/app_colors.dart mobile/lib/core/constants/app_dimens.dart mobile/lib/core/constants/app_text_styles.dart mobile/lib/core/theme/app_motion.dart mobile/lib/core/theme/app_theme.dart mobile/test/core/theme/app_theme_test.dart -m "refactor: define clinical minimal mobile theme"
```

## Task 3: 重构共享组件，建立轻量页面语言

**Files:**
- Create: `mobile/lib/shared/widgets/zy_segmented_control.dart`
- Create: `mobile/lib/shared/widgets/zy_skeleton.dart`
- Create: `mobile/lib/shared/widgets/zy_sticky_action_bar.dart`
- Create: `mobile/test/shared/widgets/zy_bottom_bar_test.dart`
- Modify: `mobile/lib/shared/widgets/widgets.dart`
- Modify: `mobile/lib/shared/widgets/zy_app_bar.dart`
- Modify: `mobile/lib/shared/widgets/zy_bottom_bar.dart`
- Modify: `mobile/lib/shared/widgets/zy_card.dart`
- Modify: `mobile/lib/shared/widgets/zy_chip.dart`
- Modify: `mobile/lib/shared/widgets/zy_empty_state.dart`
- Modify: `mobile/lib/shared/widgets/zy_list_tile.dart`
- Modify: `mobile/lib/shared/widgets/zy_section_header.dart`
- Modify: `mobile/lib/shared/widgets/zy_stat_card.dart`

- [ ] **Step 1: 写底部导航失败测试**

Create `mobile/test/shared/widgets/zy_bottom_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/shared/widgets/zy_bottom_bar.dart';

import '../../helpers/test_harness.dart';

void main() {
  const List<ZyTabSpec> tabs = <ZyTabSpec>[
    ZyTabSpec(
      path: '/',
      label: '首页',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    ZyTabSpec(
      path: '/cases',
      label: '病例',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
    ),
  ];

  testWidgets('bottom bar exposes selected semantics and handles taps',
      (WidgetTester tester) async {
    ZyTabSpec? tapped;
    await pumpPage(
      tester,
      Scaffold(
        bottomNavigationBar: ZyBottomBar(
          tabs: tabs,
          currentIndex: 0,
          onTap: (ZyTabSpec value) => tapped = value,
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('病例'), findsOneWidget);
    expect(find.byKey(const Key('bottom-tab-indicator')), findsOneWidget);
    await tester.tap(find.text('病例'));
    expect(tapped?.path, '/cases');
    expect(tester.takeException(), isNull);
  });
}
```

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/shared/widgets/zy_bottom_bar_test.dart
```

Expected: FAIL because the current bottom bar has no `bottom-tab-indicator` key and still paints a full dark selected tab.

- [ ] **Step 2: 简化 `ZyPageHead` 与 `ZyAppBar`**

Keep the public fields `kicker`, `title`, `subtitle`, and `action` to avoid a repository-wide breaking rename. Change rendering so `kicker` is a small contextual label and remove the default 56px hospital icon:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    Row(
      children: <Widget>[
        Expanded(
          child: Text(
            kicker,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (action != null) action!,
      ],
    ),
    const SizedBox(height: AppDimens.grid2),
    Text(title, style: AppTextStyles.h1),
    if (subtitle != null) ...<Widget>[
      const SizedBox(height: AppDimens.grid2),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Text(subtitle!, style: AppTextStyles.caption),
      ),
    ],
  ],
)
```

`ZyAppBar` keeps native back behavior and 44px icon targets. Do not center all titles; only dialog-like pages may request `centerTitle: true`.

Replace direct `GoRouter.of(context).canPop()` calls with `Navigator.of(context).canPop()` and use `Navigator.of(context).maybePop()` for the default back action. This preserves GoRouter's navigator behavior and lets the shared app bar render in isolated widget tests without requiring a router ancestor.

- [ ] **Step 3: 收敛卡片、标签、列表和统计组件**

Update `ZyCard` defaults:

```dart
this.padding = const EdgeInsets.all(AppDimens.cardPadding),
this.borderRadius = AppDimens.radiusCard,
this.showShadow = false,
```

Use `AppColors.line` at 1px and no default shadow. Keep `showShadow` only for true floating layers; page code should not pass it after migration.

Update `ZyChip` so non-interactive status tags use `radiusStatus`, height 24, horizontal padding 8; only an explicitly interactive filter may use `ZySegmentedControl` instead of `ZyChip.onTap`.

Update `ZyListTile` to enforce a minimum touch target:

```dart
ConstrainedBox(
  constraints: const BoxConstraints(minHeight: AppDimens.touchTarget),
  child: Padding(
    padding: padding,
    child: row,
  ),
)
```

Keep a divider between rows unless `showDivider` is false. Remove decorative colored icon squares from default usage.

`ZyStatCard` becomes a compact inline metric with no border or shadow. It may retain the class name during migration, but render label, value and detail in a simple column.

- [ ] **Step 4: 新建通用分段控件**

Create `zy_segmented_control.dart` with a typed API:

```dart
class ZySegment<T> {
  const ZySegment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class ZySegmentedControl<T> extends StatelessWidget {
  const ZySegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<ZySegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments
          .map((ZySegment<T> item) => ButtonSegment<T>(
                value: item.value,
                label: Text(item.label),
                icon: item.icon == null ? null : Icon(item.icon),
              ))
          .toList(),
      selected: <T>{value},
      onSelectionChanged: (Set<T> values) => onChanged(values.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 新建骨架与固定底部操作区**

Create `zy_skeleton.dart` with `ZySkeletonLine` and `ZySkeletonBlock`. They use `AnimatedOpacity` only when animations are enabled; no shimmer gradient:

```dart
class ZySkeletonBlock extends StatelessWidget {
  const ZySkeletonBlock({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppDimens.radiusCard,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '内容加载中',
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}
```

Create `zy_sticky_action_bar.dart`:

```dart
class ZyStickyActionBar extends StatelessWidget {
  const ZyStickyActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        elevation: 2,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: child,
        ),
      );
}
```

- [ ] **Step 6: 简化空、错、加载状态**

Keep `ZyEmptyState`, but remove the 72px decorative circle and limit it to title, detail and one action. Add a `ZyErrorState` in the same file:

```dart
class ZyErrorState extends StatelessWidget {
  const ZyErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ZyEmptyState(
        icon: Icons.refresh_rounded,
        title: '暂时无法加载',
        detail: message,
        actionLabel: '重新加载',
        onAction: onRetry,
      );
}
```

Deprecate the centered circular `ZyLoading`; page migrations must use skeletons.

- [ ] **Step 7: 重做底部导航选中态**

Render each destination with a transparent full touch area and a small rounded background behind the icon only:

```dart
AnimatedContainer(
  key: active ? const Key('bottom-tab-indicator') : null,
  duration: AppMotion.fast(context),
  curve: AppMotion.standardCurve,
  width: 36,
  height: 30,
  decoration: BoxDecoration(
    color: active ? AppColors.brandSoft : Colors.transparent,
    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
  ),
  child: Icon(
    active ? tab.activeIcon : tab.icon,
    color: active ? AppColors.brand : AppColors.muted,
  ),
)
```

Labels remain visible; selected text uses `AppColors.brand`, not white on a dark pill.

- [ ] **Step 8: 导出组件并运行测试**

Add to `widgets.dart`:

```dart
export 'zy_segmented_control.dart';
export 'zy_skeleton.dart';
export 'zy_sticky_action_bar.dart';
```

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/shared/widgets/zy_bottom_bar_test.dart test/core/theme/app_theme_test.dart
flutter analyze
```

Expected: PASS，无 RenderFlex overflow。

- [ ] **Step 9: 提交共享组件**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/shared/widgets/widgets.dart mobile/lib/shared/widgets/zy_app_bar.dart mobile/lib/shared/widgets/zy_bottom_bar.dart mobile/lib/shared/widgets/zy_card.dart mobile/lib/shared/widgets/zy_chip.dart mobile/lib/shared/widgets/zy_empty_state.dart mobile/lib/shared/widgets/zy_list_tile.dart mobile/lib/shared/widgets/zy_section_header.dart mobile/lib/shared/widgets/zy_stat_card.dart mobile/lib/shared/widgets/zy_segmented_control.dart mobile/lib/shared/widgets/zy_skeleton.dart mobile/lib/shared/widgets/zy_sticky_action_bar.dart mobile/test/shared/widgets/zy_bottom_bar_test.dart
git commit --only -- mobile/lib/shared/widgets/widgets.dart mobile/lib/shared/widgets/zy_app_bar.dart mobile/lib/shared/widgets/zy_bottom_bar.dart mobile/lib/shared/widgets/zy_card.dart mobile/lib/shared/widgets/zy_chip.dart mobile/lib/shared/widgets/zy_empty_state.dart mobile/lib/shared/widgets/zy_list_tile.dart mobile/lib/shared/widgets/zy_section_header.dart mobile/lib/shared/widgets/zy_stat_card.dart mobile/lib/shared/widgets/zy_segmented_control.dart mobile/lib/shared/widgets/zy_skeleton.dart mobile/lib/shared/widgets/zy_sticky_action_bar.dart mobile/test/shared/widgets/zy_bottom_bar_test.dart -m "refactor: simplify mobile interface primitives"
```

## Task 4: 建立最近三个月训练数据与小方块热力图

**Files:**
- Create: `mobile/lib/features/student/profile/training_activity.dart`
- Create: `mobile/lib/shared/widgets/zy_activity_heatmap.dart`
- Create: `mobile/test/shared/widgets/zy_activity_heatmap_test.dart`
- Modify: `mobile/lib/data/models/learning_model.dart`
- Modify: `mobile/lib/data/sources/mock_data.dart`
- Modify: `mobile/lib/shared/widgets/widgets.dart`

- [ ] **Step 1: 写纯逻辑和组件失败测试**

Create `mobile/test/shared/widgets/zy_activity_heatmap_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/data/models.dart';
import 'package:zhiyu/features/student/profile/training_activity.dart';
import 'package:zhiyu/shared/widgets/zy_activity_heatmap.dart';

import '../../helpers/test_harness.dart';

void main() {
  test('summary counts active days, completions and current streak', () {
    final DateTime end = DateTime(2026, 7, 15);
    final List<HeatmapDay> days = <HeatmapDay>[
      HeatmapDay(date: '2026-07-13', value: 1, completedCount: 1),
      HeatmapDay(date: '2026-07-14', value: 2, completedCount: 2),
      HeatmapDay(date: '2026-07-15', value: 1, completedCount: 1),
    ];
    final TrainingActivitySummary summary =
        TrainingActivitySummary.fromDays(days, endDate: end);
    expect(summary.activeDays, 3);
    expect(summary.completedCount, 4);
    expect(summary.currentStreak, 3);
  });

  testWidgets('heatmap renders 91 compact day cells and handles a tap',
      (WidgetTester tester) async {
    HeatmapDay? selected;
    await pumpPage(
      tester,
      Scaffold(
        body: ZyActivityHeatmap(
          days: const <HeatmapDay>[],
          endDate: DateTime(2026, 7, 15),
          onDayTap: (HeatmapDay day) => selected = day,
        ),
      ),
      size: phone360,
    );

    final Finder cells = find.byWidgetPredicate((Widget widget) {
      final Key? key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('activity-cell-');
    });
    expect(cells, findsNWidgets(91));
    await tester.tap(
      find.byKey(const ValueKey<String>('activity-cell-2026-07-15')),
    );
    expect(selected, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认类型和组件缺失**

```powershell
cd E:\zhiyu\mobile
flutter test test/shared/widgets/zy_activity_heatmap_test.dart
```

Expected: FAIL，缺少 `completedCount`、`TrainingActivitySummary` 和 `ZyActivityHeatmap`。

- [ ] **Step 3: 扩充热力日模型，不破坏旧调用**

Update `HeatmapDay`:

```dart
@immutable
class HeatmapDay {
  const HeatmapDay({
    required this.date,
    required this.value,
    this.completedCount = 0,
    this.activities = const <String>[],
  });

  final String date;
  final int value; // 0..4 visual intensity
  final int completedCount;
  final List<String> activities;

  DateTime get parsedDate => DateTime.parse(date);
}
```

- [ ] **Step 4: 实现三个月窗口与汇总**

Create `training_activity.dart` with these exact public types:

```dart
import 'package:zhiyu/data/models.dart';

class TrainingActivitySummary {
  const TrainingActivitySummary({
    required this.activeDays,
    required this.currentStreak,
    required this.completedCount,
  });

  final int activeDays;
  final int currentStreak;
  final int completedCount;

  factory TrainingActivitySummary.fromDays(
    List<HeatmapDay> days, {
    required DateTime endDate,
  }) {
    final Map<String, HeatmapDay> byDate = <String, HeatmapDay>{
      for (final HeatmapDay day in days) day.date: day,
    };
    int streak = 0;
    for (int offset = 0; offset < 91; offset++) {
      final DateTime date = DateTime(endDate.year, endDate.month, endDate.day)
          .subtract(Duration(days: offset));
      final HeatmapDay? day = byDate[_isoDate(date)];
      if (day == null || day.completedCount == 0) break;
      streak++;
    }
    return TrainingActivitySummary(
      activeDays: days.where((HeatmapDay day) => day.completedCount > 0).length,
      currentStreak: streak,
      completedCount: days.fold<int>(
        0,
        (int total, HeatmapDay day) => total + day.completedCount,
      ),
    );
  }
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

List<HeatmapDay> buildTrainingWindow(
  List<HeatmapDay> source, {
  required DateTime endDate,
}) {
  final DateTime today = DateTime(endDate.year, endDate.month, endDate.day);
  final int daysToSunday = DateTime.sunday - today.weekday;
  final DateTime windowEnd = today.add(Duration(days: daysToSunday));
  final DateTime windowStart = windowEnd.subtract(const Duration(days: 90));
  final Map<String, HeatmapDay> byDate = <String, HeatmapDay>{
    for (final HeatmapDay day in source) day.date: day,
  };

  return List<HeatmapDay>.generate(91, (int index) {
    final DateTime date = windowStart.add(Duration(days: index));
    return byDate[_isoDate(date)] ??
        HeatmapDay(date: _isoDate(date), value: 0);
  });
}
```

The widget compares each cell date with the normalized `endDate` and disables future cells.

- [ ] **Step 5: 实现紧凑热力图**

`ZyActivityHeatmap` must use a horizontal `Row` of 13 week columns, each containing 7 cells. Target dimensions are fixed and small:

```dart
static const double cellSize = 8;
static const double cellGap = 4;
static const int weekCount = 13;
static const int daysPerWeek = 7;
```

Each cell is a `Semantics` + `InkResponse` + `Container`:

```dart
Semantics(
  key: ValueKey<String>('activity-cell-${day.date}'),
  label: '${day.date}，完成 ${day.completedCount} 次训练',
  button: !isFuture,
  child: InkResponse(
    radius: 12,
    onTap: isFuture ? null : () => onDayTap(day),
    child: Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: colorFor(day.value),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  ),
)
```

Use `AppColors.brandSoft` for zero, then `activity1` through `activity4`. Do not use gradients, shadows, per-cell entrance animations, large legends or a surrounding card. Month labels derive from the first visible day in each month and render as `7月`.

- [ ] **Step 6: 生成真实最近 91 天 mock 数据**

Replace `D-83` placeholders in `mock_data.dart` with ISO dates. Use a deterministic fixed end date only in tests; production mock uses `DateTime.now()` normalized to local midnight. Populate `completedCount` and at most two concise Chinese activity labels on active days:

```dart
HeatmapDay(
  date: _isoDate(date),
  value: level,
  completedCount: level == 0 ? 0 : 1 + (index % 2),
  activities: level == 0
      ? const <String>[]
      : <String>['完成病例问诊', if (index.isEven) '复盘诊断依据'],
)
```

Keep generation deterministic for a given day; do not use random numbers.

- [ ] **Step 7: 保持仓库边界并导出组件**

Keep `LearningRepository.heatmap()` unchanged; it already returns a defensive copy. `StudentProfilePage` reads that list and calls `TrainingActivitySummary.fromDays(days, endDate: DateTime.now())` inside the feature layer. The data layer must not import a profile feature type.

Export `zy_activity_heatmap.dart` from `widgets.dart`. Do not create a provider just for derived mock data.

- [ ] **Step 8: 运行热力图、窄屏和分析测试**

```powershell
cd E:\zhiyu\mobile
flutter test test/shared/widgets/zy_activity_heatmap_test.dart
flutter analyze
```

Expected: PASS；91 cells；360px 宽无 overflow；月份文字只在边界出现（通常 3–4 个）；未来日期不可点击。

- [ ] **Step 9: 提交热力图基础**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/data/models/learning_model.dart mobile/lib/data/sources/mock_data.dart mobile/lib/features/student/profile/training_activity.dart mobile/lib/shared/widgets/zy_activity_heatmap.dart mobile/lib/shared/widgets/widgets.dart mobile/test/shared/widgets/zy_activity_heatmap_test.dart
git commit --only -- mobile/lib/data/models/learning_model.dart mobile/lib/data/sources/mock_data.dart mobile/lib/features/student/profile/training_activity.dart mobile/lib/shared/widgets/zy_activity_heatmap.dart mobile/lib/shared/widgets/widgets.dart mobile/test/shared/widgets/zy_activity_heatmap_test.dart -m "feat: add three month training heatmap"
```

## Task 5: 统一双身份应用壳、标签页动画与全屏转场

**Files:**
- Create: `mobile/test/routes/role_routing_test.dart`
- Modify: `mobile/lib/routes/app_router.dart`
- Modify: `mobile/lib/features/student/student_shell.dart`
- Modify: `mobile/lib/features/teacher/teacher_shell.dart`

- [ ] **Step 1: 写身份守卫与导航失败测试**

Create `mobile/test/routes/role_routing_test.dart` with two full-app tests:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('unauthenticated app opens the shared login',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester);
    expect(find.text('知语寻真'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
  });

  testWidgets('persisted student opens the student five-tab workspace',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester, preferences: <String, Object>{
      'zhiyu_token': 'mock-student01-token',
      'zhiyu_username': 'student01',
      'zhiyu_role': 0,
    });
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('病例'), findsOneWidget);
    expect(find.text('反馈'), findsOneWidget);
    expect(find.text('复盘'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('persisted teacher opens the teacher five-tab workspace',
      (WidgetTester tester) async {
    await pumpZhiyuApp(tester, preferences: <String, Object>{
      'zhiyu_token': 'mock-teacher01-token',
      'zhiyu_username': 'teacher01',
      'zhiyu_role': 1,
    });
    expect(find.text('概览'), findsOneWidget);
    expect(find.text('病例'), findsOneWidget);
    expect(find.text('作业'), findsOneWidget);
    expect(find.text('批阅'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
```

These tests do not depend on login-page wording. They exercise the existing persisted-session path and must pass before Task 5 is committed.

Set `GoRouter.initialLocation` to `/login`. The existing redirect already sends authenticated students to `/` and authenticated teachers to `/teacher`; starting unauthenticated users at the real entry route removes a blank intermediate frame and makes the login contract deterministic.

- [ ] **Step 2: 为标签页内容增加轻量切换**

In both shells, wrap `child` with a location-keyed `AnimatedSwitcher`:

```dart
final String location = GoRouterState.of(context).matchedLocation;
return Scaffold(
  body: AnimatedSwitcher(
    duration: AppMotion.standard(context),
    switchInCurve: AppMotion.standardCurve,
    transitionBuilder: (Widget child, Animation<double> animation) {
      final Animation<Offset> offset = Tween<Offset>(
        begin: const Offset(0.025, 0),
        end: Offset.zero,
      ).animate(animation);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: offset, child: child),
      );
    },
    child: KeyedSubtree(key: ValueKey<String>(location), child: child),
  ),
  bottomNavigationBar: ZyBottomBar(
    tabs: _tabs,
    currentIndex: index,
    onTap: (ZyTabSpec tab) {
      if (tab.path == location) return;
      context.go(tab.path);
    },
  ),
);
```

Do not animate bottom navigation dimensions. Reduced motion must yield `Duration.zero`.

- [ ] **Step 3: 为详情页面定义方向明确的推入转场**

Add a private helper in `app_router.dart`:

```dart
CustomTransitionPage<void> _detailPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.routeDuration,
    reverseTransitionDuration: AppMotion.routeDuration,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: AppMotion.standardCurve));
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SlideTransition(position: slide, child: child);
    },
  );
}
```

Use `pageBuilder` and `_detailPage` for `/student/case/:id` and `/student/chat`. Keep shell routes and role redirects unchanged. Do not create teacher detail routes solely for visual reasons; teacher review uses a sheet in Task 15.

- [ ] **Step 4: 验证路由守卫未被视觉重构破坏**

Run after implementing the shell transitions:

```powershell
cd E:\zhiyu\mobile
flutter test test/routes/role_routing_test.dart
flutter analyze
```

Expected: both identities land in their own five-tab workspace; no student route is visible to a teacher and vice versa.

- [ ] **Step 5: 提交应用壳**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/routes/app_router.dart mobile/lib/features/student/student_shell.dart mobile/lib/features/teacher/teacher_shell.dart mobile/test/routes/role_routing_test.dart
git commit --only -- mobile/lib/routes/app_router.dart mobile/lib/features/student/student_shell.dart mobile/lib/features/teacher/teacher_shell.dart mobile/test/routes/role_routing_test.dart -m "refactor: unify role workspaces and transitions"
```

## Task 6: 重构统一中文登录页并使用现有 Logo

**Files:**
- Create: `mobile/test/features/auth/login_page_test.dart`
- Modify: `mobile/lib/features/auth/login_page.dart`

- [ ] **Step 1: 写登录页行为测试**

Create `login_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/login_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('uses the existing logo and one neutral login action',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('知语寻真'), findsOneWidget);
    expect(find.text('学生'), findsOneWidget);
    expect(find.text('教师'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.textContaining('登录学生端'), findsNothing);
    expect(find.textContaining('SECURE CLINICAL NODE'), findsNothing);
  });

  testWidgets('shows inline errors for empty credentials',
      (WidgetTester tester) async {
    await pumpPage(tester, const LoginPage());
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.text('登录'));
    await tester.pump();
    expect(find.text('请输入账号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认旧版视觉文案失败**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/auth/login_page_test.dart
```

Expected: FAIL because the page uses a generated hospital icon, oversized 42px title, role-specific login text and English footer.

- [ ] **Step 3: 使用 Logo 和克制单列表单重构页面**

The top brand block must be:

```dart
Image.asset(
  'assets/images/brand-logo.png',
  width: 72,
  height: 72,
  fit: BoxFit.contain,
  semanticLabel: '知语寻真 Logo',
),
const SizedBox(height: 20),
Text('知语寻真', style: AppTextStyles.h1, textAlign: TextAlign.center),
const SizedBox(height: 8),
Text(
  '内科临床训练平台',
  style: AppTextStyles.caption,
  textAlign: TextAlign.center,
),
```

Use `ZySegmentedControl<String>` with labels `学生` and `教师`; do not call them separate “端”. Keep the current default as teacher to preserve demo behavior, and update demo credentials whenever selection changes.

Render the form directly on the page with vertical whitespace, not inside a shadowed 28px card. Use visible labels `账号` and `密码`. The button label is always `登录`; during submission show `正在登录` next to a 16px progress indicator.

Remove the English version footer. Replace dead “忘记密码” and “联系管理员” buttons with one non-interactive helper line:

```dart
const Text(
  '账号问题请联系所在教研组管理员',
  textAlign: TextAlign.center,
  style: AppTextStyles.caption,
)
```

- [ ] **Step 4: 保持键盘与小屏可用**

Use `SafeArea` + `LayoutBuilder` + `SingleChildScrollView`. Constrain content to `maxWidth: 440` and center it on tablets. Keep `onFieldSubmitted` for password and use `AutofillGroup` with username/password hints. At 360×800 and text scale 1.3, no field or button may overflow.

- [ ] **Step 5: 运行登录、路由和冒烟测试**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/auth/login_page_test.dart test/routes/role_routing_test.dart test/widget_test.dart
flutter analyze
```

Expected: PASS，学生和教师都通过同一“登录”按钮进入对应工作区。

- [ ] **Step 6: 提交登录页**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/auth/login_page.dart mobile/test/features/auth/login_page_test.dart
git commit --only -- mobile/lib/features/auth/login_page.dart mobile/test/features/auth/login_page_test.dart -m "refactor: simplify shared mobile login"
```

## Task 7: 重构学生首页，突出继续训练并移除热力图

**Files:**
- Create: `mobile/test/features/student/student_pages_test.dart`
- Modify: `mobile/lib/features/student/home/student_home_page.dart`

- [ ] **Step 1: 写学生首页目标结构测试**

Start `student_pages_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/data/models.dart';
import 'package:zhiyu/data/repositories/content_repository.dart';
import 'package:zhiyu/data/sources/mock_data.dart';
import 'package:zhiyu/features/student/cases/case_detail_page.dart';
import 'package:zhiyu/features/student/cases/cases_list_page.dart';
import 'package:zhiyu/features/student/feedback/feedback_page.dart';
import 'package:zhiyu/features/student/feedback/mistakes_page.dart';
import 'package:zhiyu/features/student/home/student_home_page.dart';
import 'package:zhiyu/features/student/profile/student_profile_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('student pages', () {
    testWidgets('home prioritizes one training action and has no heatmap',
        (WidgetTester tester) async {
      await pumpPage(tester, const StudentHomePage());
      expect(find.text('今天的训练'), findsOneWidget);
      expect(find.text('继续训练'), findsOneWidget);
      expect(find.text('最近训练'), findsOneWidget);
      expect(find.text('待复盘'), findsOneWidget);
      expect(find.text('学习热力图'), findsNothing);
      expect(find.text('MedEd Training'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认旧首页失败**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart --plain-name "home prioritizes one training action and has no heatmap"
```

Expected: FAIL because the current page still contains `MedEd Training` and `学习热力图`。

- [ ] **Step 3: 删除首页热力图依赖和统计卡行**

Remove `learningRepo.heatmap()` and `_HeatmapCard`. Keep `mistakes` only to derive the pending review count. Do not replace the removed heatmap with another chart.

The page order must be:

```dart
CustomScrollView(
  slivers: <Widget>[
    const SliverToBoxAdapter(
      child: ZyPageHead(
        kicker: '今天的训练',
        title: '从一个病例继续',
        subtitle: '完成问诊、检查决策和诊断推理。',
      ),
    ),
    SliverToBoxAdapter(child: _ContinueTraining(caseItem: daily)),
    SliverToBoxAdapter(child: _StudentTodoList(pendingMistakes: pending)),
    SliverToBoxAdapter(child: _RecentTrainingList(cases: cases.take(2).toList())),
    const SliverToBoxAdapter(child: SizedBox(height: 112)),
  ],
)
```

- [ ] **Step 4: 实现唯一主任务区**

`_ContinueTraining` is the only emphasized surface on the first screen. It uses a white 8px surface, one small status label, one 24px title and one full-width action:

```dart
ZyCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const ZyChip('每日一练'),
      const SizedBox(height: 14),
      Text(caseItem.title, style: AppTextStyles.h2),
      const SizedBox(height: 8),
      Text(caseItem.summary ?? caseItem.chief, style: AppTextStyles.body),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => context.go('/student/case/${caseItem.id}'),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('继续训练'),
      ),
    ],
  ),
)
```

Do not use a dark full-card background, gold streak text, shadow or image when no clinical image asset exists.

- [ ] **Step 5: 将待办与最近训练改成无卡片列表**

Use `ZySectionHeader` followed by `ZyListTile` rows. The two todo rows are `待复盘` and `浏览全部病例`; the recent rows show department, difficulty and duration. Only separators divide rows. Do not put a `ZyCard` around every row.

- [ ] **Step 6: 运行首页测试和三种手机宽度测试**

Add a loop in the test for `phone360`, `phone390`, `phone430`, pump the page, scroll to bottom, and assert `tester.takeException()` is null.

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart --plain-name "home prioritizes one training action and has no heatmap"
flutter analyze
```

Expected: PASS；首页不再出现热力图、英文标签或 RenderFlex overflow。

- [ ] **Step 7: 提交学生首页**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/student/home/student_home_page.dart mobile/test/features/student/student_pages_test.dart
git commit --only -- mobile/lib/features/student/home/student_home_page.dart mobile/test/features/student/student_pages_test.dart -m "refactor: focus student home on daily training"
```

## Task 8: 重构病例列表和病例详情

**Files:**
- Modify: `mobile/lib/features/student/cases/cases_list_page.dart`
- Modify: `mobile/lib/features/student/cases/case_detail_page.dart`
- Modify: `mobile/test/features/student/student_pages_test.dart`

- [ ] **Step 1: 增加病例搜索、筛选、纵向列表和固定操作测试**

Append to `student_pages_test.dart`:

```dart
testWidgets('cases use searchable compact rows', (WidgetTester tester) async {
  await pumpPage(tester, const CasesListPage());
  expect(find.widgetWithText(TextField, '搜索病例、症状或诊断'), findsOneWidget);
  expect(find.text('全部'), findsOneWidget);
  expect(find.text('心血管'), findsOneWidget);
  expect(find.text('开始问诊'), findsNothing);
  expect(tester.takeException(), isNull);
});

testWidgets('case detail has a stable start action', (WidgetTester tester) async {
  await pumpPage(tester, const CaseDetailPage(caseId: 'chest-pain'));
  expect(find.text('患者概况'), findsOneWidget);
  expect(find.text('训练目标'), findsOneWidget);
  expect(find.text('开始问诊'), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

`chest-pain` is an existing ID in `MockData.cases` and is the fixed test fixture for case detail and chat tests.

- [ ] **Step 2: 运行测试确认当前卡片布局不符合目标**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart --plain-name "cases use searchable compact rows"
flutter test test/features/student/student_pages_test.dart --plain-name "case detail has a stable start action"
```

Expected: at least one FAIL due to text/structure mismatch.

- [ ] **Step 3: 将病例列表改为搜索、分段筛选、分隔行**

Keep `_query` and `_department` state. Replace the horizontal pill filter with a horizontally scrolling underline filter for `全部 / 心血管 / 呼吸 / 消化`. Each item has a 44px minimum touch height; the selected item uses deep-teal text and a 2px bottom indicator. Do not use filled pills or shrink text.

Filter logic must remain local and deterministic:

```dart
final String query = _query.trim().toLowerCase();
final List<CaseModel> visible = all.where((CaseModel item) {
  final bool departmentMatches =
      _department == '全部' || item.department.contains(_department);
  final bool queryMatches = query.isEmpty ||
      item.title.toLowerCase().contains(query) ||
      item.chief.toLowerCase().contains(query) ||
      item.tags.any((String tag) => tag.toLowerCase().contains(query));
  return departmentMatches && queryMatches;
}).toList();
```

Each `_CaseRow` is one `InkWell` with title, chief complaint, department, difficulty and duration. The whole row navigates to detail. Remove inner “开始” buttons, large icon squares, heavy borders and shadows.

- [ ] **Step 4: 为无结果补充直接空状态**

When `visible.isEmpty`, render:

```dart
ZyEmptyState(
  title: '没有找到匹配病例',
  detail: '换一个症状、诊断名称或科室试试。',
  actionLabel: '清除筛选',
  onAction: _clearFilters,
)
```

- [ ] **Step 5: 按语义顺序重构病例详情**

Use `ZyAppBar(title: '病例详情')`, then sections in this order:

1. Patient summary: case title and chief complaint.
2. `患者概况`: department, difficulty, duration.
3. `训练目标`: render tags as compact non-interactive `ZyChip` status labels.
4. `病例资料`: summary/source when present.
5. `训练提示`: one neutral inline notice, no colored card stack.

Use `ZyStickyActionBar` in `bottomNavigationBar`:

```dart
ZyStickyActionBar(
  child: FilledButton.icon(
    onPressed: () => context.push('/student/chat?caseId=${item.id}'),
    icon: const Icon(Icons.chat_bubble_outline_rounded),
    label: const Text('开始问诊'),
  ),
)
```

If `byId` returns null, show `ZyErrorState(message: '病例不存在或已下架', onRetry: () => context.pop())` with action text adjusted to `返回病例列表`; do not force-unwrap.

- [ ] **Step 6: 验证搜索、空状态、详情导航与窄屏**

Add tests that enter a nonsense query and find `没有找到匹配病例`, then tap `清除筛选`. Test the detail page at 360×800 and text scale 1.3.

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart
flutter analyze
```

Expected: PASS，列表无横向溢出，详情底部按钮不遮挡最后一段内容。

- [ ] **Step 7: 提交病例流程**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/student/cases/cases_list_page.dart mobile/lib/features/student/cases/case_detail_page.dart mobile/test/features/student/student_pages_test.dart
git commit --only -- mobile/lib/features/student/cases/cases_list_page.dart mobile/lib/features/student/cases/case_detail_page.dart mobile/test/features/student/student_pages_test.dart -m "refactor: simplify student case discovery"
```

## Task 9: 重构问诊室、三种临床动作和消息滚动

**Files:**
- Create: `mobile/test/features/student/chat_room_page_test.dart`
- Modify: `mobile/lib/features/student/chat/chat_room_page.dart`

- [ ] **Step 1: 写问诊交互失败测试**

Create `chat_room_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/student/chat/chat_room_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('chat exposes three clinical modes and sends a question',
      (WidgetTester tester) async {
    await pumpPage(tester, const ChatRoomPage(caseId: 'chest-pain'));
    expect(find.text('询问病情'), findsOneWidget);
    expect(find.text('申请检查'), findsOneWidget);
    expect(find.text('提交判断'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '疼痛会放射到左臂吗？');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(find.text('疼痛会放射到左臂吗？'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

Confirm the test case ID against mock data before implementation.

- [ ] **Step 2: 运行测试确认缺少三模式控制**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/chat_room_page_test.dart
```

Expected: FAIL because the current chat has a dark full-screen background and no `询问病情 / 申请检查 / 提交判断` segmented control.

- [ ] **Step 3: 为消息动作建立明确本地状态**

Add:

```dart
enum ChatActionMode { question, examination, assessment }

ChatActionMode _mode = ChatActionMode.question;

String get _hintText => switch (_mode) {
  ChatActionMode.question => '向患者询问病情…',
  ChatActionMode.examination => '输入希望申请的检查…',
  ChatActionMode.assessment => '提交你的初步判断…',
};
```

Render `ZySegmentedControl<ChatActionMode>` directly above the composer. Changing mode updates the hint but does not clear existing draft text.

- [ ] **Step 4: 改为浅色沉浸式对话布局**

Use `AppColors.bg` scaffold, a white patient header with name/age/sex/status, and a pale conversation canvas. Patient messages are white with an 8px radius and a small top-left corner variation; student messages use `AppColors.brand` with white text; mentor hints use a subtle warning background and explicit `智能导师` label.

Do not use a full dark screen. The only fixed elements are patient header and bottom composer. The reasoning/cost panel opens as a modal bottom sheet from the app bar action instead of replacing the message list.

- [ ] **Step 5: 修正滚动策略**

Add:

```dart
bool get _isNearBottom => !_scrollCtrl.hasClients ||
    _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 120;

void _appendMessage(_UiMessage message) {
  final bool shouldFollow = _isNearBottom;
  setState(() => _messages.add(message));
  if (shouldFollow) _scrollToBottom();
}
```

Use `_appendMessage` for both student and simulated patient messages. Do not force scroll when the user is reading older messages. `animateTo` duration uses `AppMotion.standard(context)` and becomes immediate under reduced motion.

- [ ] **Step 6: 完善发送与键盘行为**

The composer uses `SafeArea(top: false)`, a 12px input radius and a 44×44 icon button with tooltip/semantic label `发送`. Disable sending for blank text. While the keyboard is open, the composer remains visible and the message list resizes; do not use fixed viewport heights.

Remove the dead “快速操作” plus button unless it opens a real menu. Examination and assessment modes are the supported quick actions.

- [ ] **Step 7: 测试发送、历史滚动和减少动效**

Add tests for blank send, mode switching, and a scroll-away case where adding a reply does not jump to the bottom. Use `tester.showKeyboard` to ensure no overflow at 360×800.

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/chat_room_page_test.dart
flutter analyze
```

Expected: PASS，无 overflow、setState after dispose 或未完成计时器异常。In widget tests, call `tester.pump(const Duration(milliseconds: 600))` and then `pumpAndSettle()` to complete the simulated reply.

- [ ] **Step 8: 提交问诊室**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/student/chat/chat_room_page.dart mobile/test/features/student/chat_room_page_test.dart
git commit --only -- mobile/lib/features/student/chat/chat_room_page.dart mobile/test/features/student/chat_room_page_test.dart -m "refactor: create focused clinical chat flow"
```

## Task 10: 重构能力反馈与错题复盘

**Files:**
- Modify: `mobile/lib/features/student/feedback/feedback_page.dart`
- Modify: `mobile/lib/features/student/feedback/mistakes_page.dart`
- Modify: `mobile/test/features/student/student_pages_test.dart`

- [ ] **Step 1: 增加反馈结论和复盘筛选测试**

Append:

```dart
testWidgets('feedback starts with a concise conclusion',
    (WidgetTester tester) async {
  await pumpPage(tester, const FeedbackPage());
  expect(find.text('本次表现'), findsOneWidget);
  expect(find.text('下一步建议'), findsOneWidget);
  expect(find.textContaining('MedEd'), findsNothing);
  expect(tester.takeException(), isNull);
});

testWidgets('mistakes can filter pending review items',
    (WidgetTester tester) async {
  await pumpPage(tester, const MistakesPage());
  expect(find.text('全部'), findsOneWidget);
  expect(find.text('待复盘'), findsOneWidget);
  expect(find.text('已完成'), findsOneWidget);
  await tester.tap(find.text('待复盘'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行目标测试确认当前图表/卡片结构差异**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart --plain-name "feedback starts with a concise conclusion"
flutter test test/features/student/student_pages_test.dart --plain-name "mistakes can filter pending review items"
```

- [ ] **Step 3: 将能力反馈重组为结论、维度和行动**

Order:

```text
页面标题“能力反馈”
一句结论区“本次表现”
四项能力的紧凑进度行
“下一步建议”可点击列表
```

Remove full-width gradient summary and any oversized radar/chart treatment. Ability rows use a numeric score plus a 6px linear indicator. Color is never the only signal. Learning-path rows route to existing cases/feedback destinations; if there is no real route, render as information rather than a dead button.

- [ ] **Step 4: 将错题改为状态分段和证据列表**

Use `ZySegmentedControl<String>` for `全部 / 待复盘 / 已完成`. Derive list from `reviewed` without mutating repository data. Each row displays `type`, `title`, `tag`, evidence and status, followed by one action: `开始复盘` for pending or `再次训练` for completed. Point actions to `/student/cases` until a specific mistake-to-case mapping exists; do not invent IDs.

When the filter is empty, render `当前没有待复盘内容` with `浏览病例`.

- [ ] **Step 5: 验证字体放大、空状态与列表滚动**

Add a repository override with `FakeLearningRepository extends LearningRepository` in the test and override `mistakes()` to return an empty list. Dart instance methods are overridable, so no production abstraction change is required.

```dart
class FakeLearningRepository extends LearningRepository {
  @override
  List<MistakeItem> mistakes() => const <MistakeItem>[];
}

await pumpPage(
  tester,
  const MistakesPage(),
  overrides: <Override>[
    learningRepositoryProvider.overrideWithValue(FakeLearningRepository()),
  ],
);
```

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart
flutter analyze
```

Expected: PASS；feedback and mistakes fit at 360px and text scale 1.3.

- [ ] **Step 6: 提交反馈与复盘**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/student/feedback/feedback_page.dart mobile/lib/features/student/feedback/mistakes_page.dart mobile/test/features/student/student_pages_test.dart
git commit --only -- mobile/lib/features/student/feedback/feedback_page.dart mobile/lib/features/student/feedback/mistakes_page.dart mobile/test/features/student/student_pages_test.dart -m "refactor: clarify feedback and review actions"
```

## Task 11: 重构学生“我的”并接入三个月热力图

**Files:**
- Modify: `mobile/lib/features/student/profile/student_profile_page.dart`
- Modify: `mobile/test/features/student/student_pages_test.dart`

- [ ] **Step 1: 增加 Logo、三项数据和热力图位置测试**

Append:

```dart
testWidgets('student profile owns the compact three-month heatmap',
    (WidgetTester tester) async {
  await pumpPage(tester, const StudentProfilePage());
  expect(find.byType(Image), findsOneWidget);
  expect(find.text('训练天数'), findsOneWidget);
  expect(find.text('连续天数'), findsOneWidget);
  expect(find.text('完成次数'), findsOneWidget);
  expect(find.text('最近三个月'), findsOneWidget);
  final Finder cells = find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('activity-cell-');
  });
  expect(cells, findsNWidgets(91));
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行测试确认热力图尚未迁移**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart --plain-name "student profile owns the compact three-month heatmap"
```

Expected: FAIL because the current profile has no heatmap and uses a gradient header plus three generic stat cards.

- [ ] **Step 3: 用现有 Logo 重构身份区**

Replace the gradient header and generated person icon with:

```dart
Row(
  children: <Widget>[
    Image.asset(
      'assets/images/brand-logo.png',
      width: 56,
      height: 56,
      fit: BoxFit.contain,
      semanticLabel: '知语寻真 Logo',
    ),
    const SizedBox(width: 16),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(user?.displayName ?? '同学', style: AppTextStyles.h3),
          Text('${user?.orgName ?? '未设置班级'} · 学生',
              style: AppTextStyles.caption),
        ],
      ),
    ),
  ],
)
```

Do not place the Logo inside a circle or colored square.

- [ ] **Step 4: 添加紧凑统计和热力图**

Convert `StudentProfilePage` from `ConsumerWidget` to `ConsumerStatefulWidget` so it can store the selected empty-day message without mutating repository data. Watch `learningRepositoryProvider`, obtain `days`, and compute `TrainingActivitySummary.fromDays(days, endDate: DateTime.now())` in `build`. Render three equal text columns with vertical dividers. Labels must be exactly `训练天数 / 连续天数 / 完成次数`.

Below `ZySectionHeader(title: '最近三个月')`, render `ZyActivityHeatmap` directly in page whitespace. On tap, call a private `_showDayDetail`:

```dart
void _showDayDetail(BuildContext context, HeatmapDay day) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(day.date, style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text('完成 ${day.completedCount} 次训练', style: AppTextStyles.body),
          if (day.activities.isNotEmpty) ...day.activities.map(
            (String item) => ZyListTile(title: item, showDivider: false),
          ),
        ],
      ),
    ),
  );
}
```

For zero-activity days, tapping should only update a small inline text `当天没有训练记录`, not open an empty sheet.

- [ ] **Step 5: 简化菜单和免责声明**

Keep only working menu rows: `训练历史` routes to `/student/feedback` and `收藏病例` routes to `/student/cases`. Render them with dividers, not inside one large rounded card. Remove the dead notification and settings rows. Keep the disclaimer and logout below the menu.

The medical disclaimer remains a restrained inline notice. Logout is an outlined danger action separated by at least 24px whitespace.

- [ ] **Step 6: 验证三个月密度和点击详情**

In the test, read `MockData.heatmapDays.firstWhere((HeatmapDay day) => day.completedCount > 0)`, tap its `ValueKey('activity-cell-${day.date}')`, and assert `完成 ${day.completedCount} 次训练`. Then close the sheet by dragging down. Pump at 360×800, 390×844 and 430×932.

```dart
final HeatmapDay active = MockData.heatmapDays
    .firstWhere((HeatmapDay day) => day.completedCount > 0);
await tester.tap(
  find.byKey(ValueKey<String>('activity-cell-${active.date}')),
);
await tester.pumpAndSettle();
expect(find.text('完成 ${active.completedCount} 次训练'), findsOneWidget);
await tester.drag(find.text(active.date), const Offset(0, 500));
await tester.pumpAndSettle();
```

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/student/student_pages_test.dart test/shared/widgets/zy_activity_heatmap_test.dart
flutter analyze
```

Expected: PASS；exactly 91 small cells；page itself has no horizontal overflow；heatmap has no surrounding `ZyCard`.

- [ ] **Step 7: 提交学生个人页**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/student/profile/student_profile_page.dart mobile/test/features/student/student_pages_test.dart
git commit --only -- mobile/lib/features/student/profile/student_profile_page.dart mobile/test/features/student/student_pages_test.dart -m "refactor: move training activity to student profile"
```

## Task 12: 重构教师概览为今日教学待办

**Files:**
- Create: `mobile/test/features/teacher/teacher_pages_test.dart`
- Modify: `mobile/lib/features/teacher/overview/teacher_overview_page.dart`

- [ ] **Step 1: 写教师概览优先级测试**

Create `teacher_pages_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/teacher/assignments/assignments_page.dart';
import 'package:zhiyu/features/teacher/cases/case_config_page.dart';
import 'package:zhiyu/features/teacher/cases/case_market_page.dart';
import 'package:zhiyu/features/teacher/overview/teacher_overview_page.dart';
import 'package:zhiyu/features/teacher/profile/teacher_profile_page.dart';
import 'package:zhiyu/features/teacher/review/review_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('teacher pages', () {
    testWidgets('overview starts with actionable teaching work',
        (WidgetTester tester) async {
      await pumpPage(tester, const TeacherOverviewPage());
      expect(find.text('今天需要处理'), findsOneWidget);
      expect(find.text('待复核'), findsWidgets);
      expect(find.text('作业进度'), findsOneWidget);
      expect(find.text('班级薄弱点'), findsOneWidget);
      expect(find.textContaining('Faculty'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认旧概览结构不匹配**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart --plain-name "overview starts with actionable teaching work"
```

Expected: FAIL or structure mismatch because current overview starts from large heading and equal stat cards.

- [ ] **Step 3: 按行动顺序重组概览**

Target sliver order:

```dart
CustomScrollView(
  slivers: <Widget>[
    const SliverToBoxAdapter(
      child: ZyPageHead(
        kicker: '教学概览',
        title: '今天需要处理',
        subtitle: '优先确认争议批阅，再查看作业进度。',
      ),
    ),
    SliverToBoxAdapter(
      child: _PriorityActions(
        pendingCount: pending,
        disputedCount: disputed,
      ),
    ),
    SliverToBoxAdapter(
      child: _AssignmentProgress(assignments: assignments),
    ),
    SliverToBoxAdapter(
      child: _WeaknessList(items: weakness),
    ),
    SliverToBoxAdapter(
      child: _CaseShortcuts(
        onCases: () => context.go('/teacher/cases'),
        onMarket: () => context.go('/teacher/market'),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 112)),
  ],
)
```

`_PriorityActions` uses two `ZyListTile` rows: `待复核 N 项` routes to `/teacher/review`; `配置新病例` routes to `/teacher/cases`. Do not use two equal stat cards.

- [ ] **Step 4: 用行内数据表达作业和薄弱点**

Assignment progress is one section showing submitted/total plus a 6px linear bar. Weakness rows show tag, average mastery percentage and occurrence count. Use text plus progress; do not add a radar chart or colored card per weakness.

Only the single highest-priority pending review item may use a bordered surface. Other content uses lists and separators.

- [ ] **Step 5: 测试导航目标和三种尺寸**

Keep this page test structural and leave route transitions to `role_routing_test.dart`. Test 360, 390 and 430 widths, scroll to the bottom, and assert no exceptions.

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart
flutter analyze
```

Expected: PASS，首屏可看到一个明确待办，不出现三张统计卡网格。

- [ ] **Step 6: 提交教师概览**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/teacher/overview/teacher_overview_page.dart mobile/test/features/teacher/teacher_pages_test.dart
git commit --only -- mobile/lib/features/teacher/overview/teacher_overview_page.dart mobile/test/features/teacher/teacher_pages_test.dart -m "refactor: prioritize teacher daily actions"
```

## Task 13: 重构教师病例配置与病例广场

**Files:**
- Modify: `mobile/lib/features/teacher/cases/case_config_page.dart`
- Modify: `mobile/lib/features/teacher/cases/case_market_page.dart`
- Modify: `mobile/test/features/teacher/teacher_pages_test.dart`

- [ ] **Step 1: 增加病例表单和广场列表测试**

Append:

```dart
testWidgets('case configuration is a labeled form with one save action',
    (WidgetTester tester) async {
  await pumpPage(tester, const CaseConfigPage());
  expect(find.text('病例配置'), findsOneWidget);
  expect(find.text('基本信息'), findsOneWidget);
  expect(find.text('教学目标'), findsOneWidget);
  expect(find.text('保存配置'), findsOneWidget);
  expect(tester.takeException(), isNull);
});

testWidgets('case market uses readable rows with one primary action',
    (WidgetTester tester) async {
  await pumpPage(tester, const CaseMarketPage());
  expect(find.text('病例广场'), findsOneWidget);
  expect(find.text('引用病例'), findsWidgets);
  expect(find.text('查看详情'), findsNothing);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行测试确认旧配置和双按钮卡片失败**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart --plain-name "case configuration is a labeled form with one save action"
flutter test test/features/teacher/teacher_pages_test.dart --plain-name "case market uses readable rows with one primary action"
```

- [ ] **Step 3: 把病例配置拆成清楚表单分组**

Keep existing controllers and local state. Organize fields under unframed section headers:

```text
基本信息：病例标题、患者年龄、主诉、初步诊断
模拟病人：沟通特点、配合程度
教学目标：知识点标签、难度
预览：学生将看到的简短病例摘要
```

Every field has a visible label and inline validator. Use `AutovalidateMode.onUserInteraction`. Do not place each section in a separate shadow card. Use a single `Form` and `ZyStickyActionBar` with `保存配置`.

Implement `_save()` as an honest local demo action: validate, unfocus keyboard, set `_saving = true`, wait 300ms, keep the edited values in page state, set `_saving = false`, then show `演示配置已保存`. Do not claim backend persistence.

- [ ] **Step 4: 保留已配置病例为次级列表**

Below the form preview, show configured cases as compact rows. Remove card-per-case and multiple row buttons. Put the `病例广场` text action in that section header and route it to `/teacher/market`.

- [ ] **Step 5: 将病例广场改成搜索 + 列表**

Add a search field and department filter using the same visual language as the student cases page. Each market row contains title, author, department, difficulty, rating, reference count and certified text. The only row action is `引用病例`; tapping non-action row space has no handler.

Convert `CaseMarketPage` from `ConsumerWidget` to `ConsumerStatefulWidget` to own `_query`, `_department` and the local set of referenced case titles.

For the demo, tapping `引用病例` changes local state to `已引用` and disables the button. Show a short SnackBar `病例已加入你的病例库`; no exclamation mark.

- [ ] **Step 6: 验证表单错误、键盘和引用状态**

Add tests: clear required title, tap save, expect `请输入病例标题`; enter a title, save, expect success; tap `引用病例`, expect `已引用`. Use 360×800 with keyboard open.

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart
flutter analyze
```

Expected: PASS；no dead buttons；no nested cards；keyboard does not hide save action.

- [ ] **Step 7: 提交教师病例模块**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/teacher/cases/case_config_page.dart mobile/lib/features/teacher/cases/case_market_page.dart mobile/test/features/teacher/teacher_pages_test.dart
git commit --only -- mobile/lib/features/teacher/cases/case_config_page.dart mobile/lib/features/teacher/cases/case_market_page.dart mobile/test/features/teacher/teacher_pages_test.dart -m "refactor: simplify teacher case workflow"
```

## Task 14: 重构教师作业列表与格式规则

**Files:**
- Modify: `mobile/lib/features/teacher/assignments/assignments_page.dart`
- Modify: `mobile/test/features/teacher/teacher_pages_test.dart`

- [ ] **Step 1: 增加作业列表信息密度测试**

Append:

```dart
testWidgets('assignments show status, deadline and inline progress',
    (WidgetTester tester) async {
  await pumpPage(tester, const AssignmentsPage());
  expect(find.text('作业'), findsWidgets);
  expect(find.text('提交进度'), findsWidgets);
  expect(find.text('格式规则'), findsOneWidget);
  expect(find.text('编辑规则'), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行测试确认标题或规则文案不匹配**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart --plain-name "assignments show status, deadline and inline progress"
```

- [ ] **Step 3: 将作业卡片改为分隔列表行**

Each assignment row uses this content order:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    Row(children: <Widget>[
      Expanded(child: Text(item.title, style: AppTextStyles.title)),
      ZyChip(item.status, tone: statusTone),
    ]),
    Text('${item.className} · 截止 ${item.due}', style: AppTextStyles.caption),
    Row(children: <Widget>[
      const Text('提交进度'),
      const Spacer(),
      Text('${item.submitted} / ${item.total}'),
    ]),
    ZyProgress(value: item.progress),
  ],
)
```

Do not use `showShadow: true`, 9px progress bars or multiple chip rows. Show `需大病历` and variable policy as one concise metadata line.

- [ ] **Step 4: 把格式盾牌改为规则区**

Rename visible section to `格式规则`. Each rule is one row: state label, rule name, short detail. `编辑规则` opens a small bottom sheet listing three local switches only if those switches already map to existing rules; otherwise show a read-only sheet titled `格式规则说明`. Do not leave `onPressed: () {}`.

The page-level `新建作业` action opens a minimal creation sheet with title, class and deadline validation. The sheet uses `isScrollControlled: true`, follows the keyboard, and adds the valid assignment to page-local state.

Convert `AssignmentsPage` from `ConsumerWidget` to `ConsumerStatefulWidget`. Initialize `_assignments` from `teachingRepositoryProvider` in `initState`, and mutate only that page-local list when the demo creation sheet succeeds.

- [ ] **Step 5: 添加新建作业表单测试**

Tap `新建作业`, expect fields `作业名称 / 班级 / 截止日期` and action `创建作业`. Submit empty and expect `请输入作业名称`. In demo mode, valid submit adds a local row and shows `作业已创建`.

- [ ] **Step 6: 运行作业测试和分析**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart
flutter analyze
```

Expected: PASS；all visible actions work；progress remains aligned with large text.

- [ ] **Step 7: 提交作业模块**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/teacher/assignments/assignments_page.dart mobile/test/features/teacher/teacher_pages_test.dart
git commit --only -- mobile/lib/features/teacher/assignments/assignments_page.dart mobile/test/features/teacher/teacher_pages_test.dart -m "refactor: clarify assignment progress and rules"
```

## Task 15: 重构批阅队列并实现可拖动详情层

**Files:**
- Create: `mobile/lib/features/teacher/review/review_detail_sheet.dart`
- Modify: `mobile/lib/features/teacher/review/review_page.dart`
- Modify: `mobile/test/features/teacher/teacher_pages_test.dart`

- [ ] **Step 1: 增加筛选、详情滑入和操作测试**

Append:

```dart
testWidgets('review opens a draggable detail sheet with explicit actions',
    (WidgetTester tester) async {
  await pumpPage(tester, const ReviewPage());
  expect(find.text('待复核'), findsWidgets);
  await tester.tap(find.text('复核').first);
  await tester.pumpAndSettle();
  expect(find.text('批阅详情'), findsOneWidget);
  expect(find.text('通过'), findsOneWidget);
  expect(find.text('退回修改'), findsOneWidget);
  expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行测试确认当前按钮为空实现**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart --plain-name "review opens a draggable detail sheet with explicit actions"
```

Expected: FAIL because current `查看` and `复核` buttons use empty callbacks.

- [ ] **Step 3: 将队列卡改为一整行可点击对象**

Keep filters `全部 / 待复核 / 已初步批阅 / 有争议项` in a compact horizontally scrolling underline filter. Each queue row shows student, assignment, score, status and one-line issue. Remove separate `查看` and `复核` buttons; tapping the row opens the detail sheet.

Top metrics become one inline summary sentence such as `待复核 3 项，其中 1 项有争议`, not two stat cards.

- [ ] **Step 4: 实现 `ReviewDetailSheet`**

Create a focused public widget:

```dart
class ReviewDetailSheet extends StatelessWidget {
  const ReviewDetailSheet({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReturn,
  });

  final ReviewItem item;
  final VoidCallback onApprove;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: <Widget>[
            Text('批阅详情', style: AppTextStyles.h2),
            Text('${item.student} · ${item.assignment}',
                style: AppTextStyles.caption),
            const SizedBox(height: 24),
            const ZySectionHeader(title: '问题证据'),
            Text(item.issue, style: AppTextStyles.body),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onReturn, child: const Text('退回修改')),
            const SizedBox(height: 10),
            FilledButton(onPressed: onApprove, child: const Text('通过')),
          ],
        );
      },
    );
  }
}
```

Open it with `showModalBottomSheet(isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent)` and a white `radiusSheet` container. The sheet must dismiss by downward drag and back button.

- [ ] **Step 5: 实现本地处理状态**

Copy repository queue into `_queue` during `initState`. Approve changes status to `已复核`; return changes it to `待修改` for this demo session. Close the sheet and show `复核结果已提交` or `已退回修改`. Do not mutate `MockData` globally.

- [ ] **Step 6: 测试操作、内部滚动和下滑关闭**

Add tests for approve and return paths. Drag the sheet down with `tester.drag(find.text('批阅详情'), const Offset(0, 500))`, pump, and expect the title disappears. At 360×800 and text scale 1.3, actions remain reachable by scrolling.

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart
flutter analyze
```

Expected: PASS；no desktop split layout；no dead action buttons。

- [ ] **Step 7: 提交批阅模块**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/teacher/review/review_page.dart mobile/lib/features/teacher/review/review_detail_sheet.dart mobile/test/features/teacher/teacher_pages_test.dart
git commit --only -- mobile/lib/features/teacher/review/review_page.dart mobile/lib/features/teacher/review/review_detail_sheet.dart mobile/test/features/teacher/teacher_pages_test.dart -m "refactor: add focused teacher review sheet"
```

## Task 16: 重构教师“我的”并统一身份结构

**Files:**
- Modify: `mobile/lib/features/teacher/profile/teacher_profile_page.dart`
- Modify: `mobile/test/features/teacher/teacher_pages_test.dart`

- [ ] **Step 1: 增加 Logo、身份信息和无热力图测试**

Append:

```dart
testWidgets('teacher profile shares identity structure without heatmap',
    (WidgetTester tester) async {
  await pumpPage(tester, const TeacherProfilePage());
  expect(find.byType(Image), findsOneWidget);
  expect(find.text('教师'), findsOneWidget);
  expect(find.text('教学概况'), findsOneWidget);
  expect(find.text('最近三个月'), findsNothing);
  final Finder cells = find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('activity-cell-');
  });
  expect(cells, findsNothing);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行测试确认当前渐变头像卡失败**

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart --plain-name "teacher profile shares identity structure without heatmap"
```

- [ ] **Step 3: 复用学生身份区的视觉结构**

Use the same 56px raw Logo, name, organization and role line. Show credential status as plain text plus verified icon, not a decorative avatar circle. Remove gradient background.

The visible page order is:

```text
身份信息
教学概况：本月批阅 / 配置病例 / 活跃班级
常用入口：我的班级 / 我的病例 / 教学洞察
医学教学说明
退出登录
```

Render teaching metrics as inline columns with dividers. Do not use three `ZyStatCard` containers.

- [ ] **Step 4: 移除无真实行为的菜单项**

Keep only routes that work:

- `我的班级` -> `/teacher/assignments`
- `我的病例` -> `/teacher/cases`
- `教学洞察` -> `/teacher`

Remove `服务健康` and `应用设置` instead of leaving empty callbacks. Menu rows are unframed and separated by dividers.

- [ ] **Step 5: 测试路由、退出和三种屏幕宽度**

Add a full-App teacher test using persisted teacher preferences: tap bottom `我的`, tap `我的班级`, assert the assignments page appears; return to `我的`, tap `退出登录`, and assert `知语寻真` and the login form appear.

```dart
testWidgets('teacher profile routes to assignments and logs out',
    (WidgetTester tester) async {
  await pumpZhiyuApp(tester, preferences: <String, Object>{
    'zhiyu_token': 'mock-teacher01-token',
    'zhiyu_username': 'teacher01',
    'zhiyu_role': 1,
  });
  await tester.tap(find.text('我的').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('我的班级'));
  await tester.pumpAndSettle();
  expect(find.text('提交进度'), findsWidgets);

  await tester.tap(find.text('我的').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('退出登录'));
  await tester.pumpAndSettle();
  expect(find.text('知语寻真'), findsOneWidget);
  expect(find.text('账号'), findsOneWidget);
}
```

Run:

```powershell
cd E:\zhiyu\mobile
flutter test test/features/teacher/teacher_pages_test.dart test/routes/role_routing_test.dart
flutter analyze
```

Expected: PASS；teacher profile has no student heatmap；all visible menu rows are functional.

- [ ] **Step 6: 提交教师个人页**

```powershell
cd E:\zhiyu
git diff --check -- mobile/lib/features/teacher/profile/teacher_profile_page.dart mobile/test/features/teacher/teacher_pages_test.dart
git commit --only -- mobile/lib/features/teacher/profile/teacher_profile_page.dart mobile/test/features/teacher/teacher_pages_test.dart -m "refactor: align teacher profile with shared app"
```

## Task 17: 补齐响应式、字体缩放、状态和可访问性回归

**Files:**
- Create: `mobile/test/accessibility/responsive_smoke_test.dart`
- Modify: `mobile/test/helpers/test_harness.dart`
- Modify if its smoke case fails: `mobile/lib/features/auth/login_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/student/home/student_home_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/student/cases/cases_list_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/student/cases/case_detail_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/student/chat/chat_room_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/student/feedback/feedback_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/student/feedback/mistakes_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/student/profile/student_profile_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/teacher/overview/teacher_overview_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/teacher/cases/case_config_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/teacher/cases/case_market_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/teacher/assignments/assignments_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/teacher/review/review_page.dart`
- Modify if its smoke case fails: `mobile/lib/features/teacher/review/review_detail_sheet.dart`
- Modify if its smoke case fails: `mobile/lib/features/teacher/profile/teacher_profile_page.dart`

- [ ] **Step 1: 让测试装配支持字体缩放和动效开关**

Extend `pumpPage`:

```dart
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = phone390,
  List<Override> overrides = const <Override>[],
  bool disableAnimations = true,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: page,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: 创建全页面响应式冒烟测试**

Create `mobile/test/accessibility/responsive_smoke_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyu/features/auth/login_page.dart';
import 'package:zhiyu/features/student/cases/case_detail_page.dart';
import 'package:zhiyu/features/student/cases/cases_list_page.dart';
import 'package:zhiyu/features/student/chat/chat_room_page.dart';
import 'package:zhiyu/features/student/feedback/feedback_page.dart';
import 'package:zhiyu/features/student/feedback/mistakes_page.dart';
import 'package:zhiyu/features/student/home/student_home_page.dart';
import 'package:zhiyu/features/student/profile/student_profile_page.dart';
import 'package:zhiyu/features/teacher/assignments/assignments_page.dart';
import 'package:zhiyu/features/teacher/cases/case_config_page.dart';
import 'package:zhiyu/features/teacher/cases/case_market_page.dart';
import 'package:zhiyu/features/teacher/overview/teacher_overview_page.dart';
import 'package:zhiyu/features/teacher/profile/teacher_profile_page.dart';
import 'package:zhiyu/features/teacher/review/review_page.dart';

import '../helpers/test_harness.dart';

void main() {
  final Map<String, Widget> pages = <String, Widget>{
    '登录': const LoginPage(),
    '学生首页': const StudentHomePage(),
    '病例列表': const CasesListPage(),
    '病例详情': const CaseDetailPage(caseId: 'chest-pain'),
    '问诊室': const ChatRoomPage(caseId: 'chest-pain'),
    '能力反馈': const FeedbackPage(),
    '错题复盘': const MistakesPage(),
    '学生我的': const StudentProfilePage(),
    '教师概览': const TeacherOverviewPage(),
    '病例配置': const CaseConfigPage(),
    '病例广场': const CaseMarketPage(),
    '作业': const AssignmentsPage(),
    '批阅': const ReviewPage(),
    '教师我的': const TeacherProfilePage(),
  };

  for (final MapEntry<String, Widget> entry in pages.entries) {
    testWidgets('${entry.key} fits 360x800 at 1.3 text scale',
        (WidgetTester tester) async {
      await pumpPage(
        tester,
        entry.value,
        size: phone360,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
```

The fixed fixture `chest-pain` exists in `MockData.cases`; do not replace it with an invented ID.

- [ ] **Step 3: 运行测试，逐项修复真实溢出**

```powershell
cd E:\zhiyu\mobile
flutter test test/accessibility/responsive_smoke_test.dart
```

Expected on first run: one or more failures are acceptable. Fix each failure locally:

- Wrap row text in `Expanded` or `Flexible`.
- Allow titles to wrap to two lines.
- Move trailing metadata below the title when width is insufficient.
- Use `Wrap` for action groups.
- Keep button height stable; do not reduce font below 13px to force fit.
- Never restore global `TextScaler.noScaling`.

Re-run until all cases pass.

- [ ] **Step 4: 检查触控目标和语义**

For icon-only actions, verify `tooltip` or `Semantics(label:)` exists. Add targeted assertions:

```dart
final SemanticsHandle handle = tester.ensureSemantics();
expect(find.bySemanticsLabel('发送'), findsOneWidget);
expect(find.bySemanticsLabel('知语寻真 Logo'), findsOneWidget);
handle.dispose();
```

Check primary controls are at least 44×44 using `tester.getSize(finder)`.

- [ ] **Step 5: 检查加载、空、错、成功四类状态**

Use Provider overrides or local state to exercise:

| State | Page | Required visible result |
| --- | --- | --- |
| Loading | 登录提交 | `正在登录` and disabled submit button |
| Empty | 病例 search | `没有找到匹配病例` + `清除筛选` |
| Empty | 错题 pending filter | `当前没有待复盘内容` + `浏览病例` |
| Error | invalid case ID | `病例不存在或已下架` + return action |
| Success | case config | `演示配置已保存` |
| Success | assignment create | `作业已创建` |
| Success | review approve | `复核结果已提交` |

Do not add fake network delays beyond what a test needs. Skeleton components are tested directly until asynchronous repositories exist.

- [ ] **Step 6: 运行完整测试和分析**

```powershell
cd E:\zhiyu\mobile
flutter test
flutter analyze
```

Expected: exit 0; no `overflowed by`, pending timer, semantics or deprecation failures.

- [ ] **Step 7: 提交响应式和可访问性修复**

List exact files changed by this task before committing:

```powershell
cd E:\zhiyu
git diff --name-only -- mobile
git diff --check -- mobile/test/helpers/test_harness.dart mobile/test/accessibility/responsive_smoke_test.dart
```

Commit only the harness, the new smoke test and page files actually changed:

```powershell
git commit --only -- mobile/test/helpers/test_harness.dart mobile/test/accessibility/responsive_smoke_test.dart mobile/lib/features/auth/login_page.dart mobile/lib/features/student/home/student_home_page.dart mobile/lib/features/student/cases/cases_list_page.dart mobile/lib/features/student/cases/case_detail_page.dart mobile/lib/features/student/chat/chat_room_page.dart mobile/lib/features/student/feedback/feedback_page.dart mobile/lib/features/student/feedback/mistakes_page.dart mobile/lib/features/student/profile/student_profile_page.dart mobile/lib/features/teacher/overview/teacher_overview_page.dart mobile/lib/features/teacher/cases/case_config_page.dart mobile/lib/features/teacher/cases/case_market_page.dart mobile/lib/features/teacher/assignments/assignments_page.dart mobile/lib/features/teacher/review/review_page.dart mobile/lib/features/teacher/review/review_detail_sheet.dart mobile/lib/features/teacher/profile/teacher_profile_page.dart -m "test: harden mobile responsive behavior"
```

## Task 18: 最终清理、反过度设计审计和交付验证

**Files:**
- Modify if the token audit fails: `mobile/lib/core/constants/app_colors.dart`
- Modify if the token audit fails: `mobile/lib/core/constants/app_dimens.dart`
- Modify if the typography audit fails: `mobile/lib/core/constants/app_text_styles.dart`
- Modify if the theme audit fails: `mobile/lib/core/theme/app_theme.dart`
- Modify if the component audit fails: `mobile/lib/shared/widgets/zy_app_bar.dart`
- Modify if the component audit fails: `mobile/lib/shared/widgets/zy_bottom_bar.dart`
- Modify if the component audit fails: `mobile/lib/shared/widgets/zy_card.dart`
- Modify if the component audit fails: `mobile/lib/shared/widgets/zy_chip.dart`
- Modify if the component audit fails: `mobile/lib/shared/widgets/zy_empty_state.dart`
- Modify if the component audit fails: `mobile/lib/shared/widgets/zy_stat_card.dart`
- Modify if the page audit fails: `mobile/lib/features/auth/login_page.dart`
- Modify if the page audit fails: `mobile/lib/features/student/home/student_home_page.dart`
- Modify if the page audit fails: `mobile/lib/features/student/cases/cases_list_page.dart`
- Modify if the page audit fails: `mobile/lib/features/student/cases/case_detail_page.dart`
- Modify if the page audit fails: `mobile/lib/features/student/chat/chat_room_page.dart`
- Modify if the page audit fails: `mobile/lib/features/student/feedback/feedback_page.dart`
- Modify if the page audit fails: `mobile/lib/features/student/feedback/mistakes_page.dart`
- Modify if the page audit fails: `mobile/lib/features/student/profile/student_profile_page.dart`
- Modify if the page audit fails: `mobile/lib/features/teacher/overview/teacher_overview_page.dart`
- Modify if the page audit fails: `mobile/lib/features/teacher/cases/case_config_page.dart`
- Modify if the page audit fails: `mobile/lib/features/teacher/cases/case_market_page.dart`
- Modify if the page audit fails: `mobile/lib/features/teacher/assignments/assignments_page.dart`
- Modify if the page audit fails: `mobile/lib/features/teacher/review/review_page.dart`
- Modify if the page audit fails: `mobile/lib/features/teacher/review/review_detail_sheet.dart`
- Modify if the page audit fails: `mobile/lib/features/teacher/profile/teacher_profile_page.dart`
- Verify: `mobile/lib/`
- Verify: `mobile/test/`
- Verify: `mobile/assets/images/brand-logo.png`

- [ ] **Step 1: 扫描英文可见文案、乱码和死按钮**

Run:

```powershell
cd E:\zhiyu
rg -n "MedEd|Faculty|SECURE CLINICAL NODE|Login|Profile|Review|Cases" mobile/lib/features -g "*.dart"
rg -n "锟|�|鐭|璇|闂|鎴|绔" mobile/lib -g "*.dart"
rg -n "onPressed:\s*\(\)\s*\{\s*\}|onTap:\s*\(\)\s*\{\s*\}" mobile/lib/features -g "*.dart"
```

Expected: no user-visible English labels, no mojibake, no empty callbacks. Technical class names and import paths are allowed. For every match, inspect the rendered string context before changing it.

- [ ] **Step 2: 扫描过度设计残留**

```powershell
cd E:\zhiyu
rg -n "LinearGradient|RadialGradient|showShadow:\s*true|radiusPill|fontSize:\s*(3[0-9]|4[0-9])|FontWeight\.w900" mobile/lib/features mobile/lib/shared -g "*.dart"
rg -n "ZyCard\(" mobile/lib/features -g "*.dart"
```

Review every match against these limits:

- No page background gradients.
- No `showShadow: true` on ordinary page content.
- Pill radius only for short status or a familiar system control, never whole cards/buttons.
- No 30px+ page heading.
- `w900` only if a small numeric metric genuinely needs it; ordinary titles use 600–700.
- No card inside another card.
- Each screen should have at most one visually emphasized surface before scrolling.

Fix violations and add a short code comment only where an exception is semantically necessary.

- [ ] **Step 3: 清理迁移别名和未使用组件**

Run:

```powershell
cd E:\zhiyu
rg -n "radius(Sm|Md|Lg|Xl|Xxl)|bgGradientTop|AppColors\.deep|shadow(Soft|Card)?|ZyLoading|ZyStatCard" mobile/lib -g "*.dart"
```

Replace remaining page usages with `radiusCard`, `radiusControl`, `radiusSheet`, skeletons and inline metrics. When `rg` shows zero usages, remove compatibility aliases and obsolete color/shadow constants. Remove `ZyLoading` or `ZyStatCard` only if zero production usages remain; otherwise keep them private to a justified legacy area and document the reason.

- [ ] **Step 4: 格式化并检查差异质量**

```powershell
cd E:\zhiyu\mobile
dart format lib test
cd E:\zhiyu
git diff --check -- mobile
git diff --stat -- mobile
```

Expected: no whitespace errors. Inspect the stat for unexpected changes in generated platform files; do not commit generated plugin registrants unless dependency metadata actually changed.

- [ ] **Step 5: 运行完整自动验证**

```powershell
cd E:\zhiyu\mobile
flutter pub get
flutter analyze
flutter test
flutter test --coverage
flutter build apk --debug
```

Expected:

- `flutter pub get`: exit 0, no unplanned dependency additions.
- `flutter analyze`: `No issues found!`.
- `flutter test`: all tests pass.
- `flutter test --coverage`: creates `coverage/lcov.info`.
- `flutter build apk --debug`: exit 0 and prints the APK output path.

- [ ] **Step 6: 启动模拟器或真机进行交互检查**

```powershell
cd E:\zhiyu\mobile
$devices = flutter devices --machine | ConvertFrom-Json
$deviceId = ($devices | Where-Object { $_.targetPlatform -match 'android|ios' } | Select-Object -First 1).id
if (-not $deviceId) { throw '未发现 Android 或 iOS 设备，请先启动模拟器或连接真机' }
flutter run -d $deviceId
```

Use a real device ID from `flutter devices`. Check both demo accounts:

```text
学生：student01 / 123456
教师：teacher01 / 123456
```

Manual flow checklist:

1. Login as student; switch identity before login; show/hide password; submit with keyboard.
2. Switch all five student tabs; confirm short fade/slide and stable bottom bar.
3. Search/filter cases; open detail; start chat; swipe back.
4. Switch chat modes; send a message; scroll history; open/close reasoning sheet; test keyboard.
5. Open feedback and mistakes; filter pending/completed.
6. Open student profile; verify 91 tiny heatmap squares; tap active and empty days; dismiss detail sheet.
7. Logout; login as teacher.
8. Switch all five teacher tabs.
9. Validate case form errors; save a demo case; enter market; reference one case.
10. Create a demo assignment; open format rules.
11. Filter review queue; open sheet; scroll; drag down; approve and return separate items.
12. Open teacher profile; confirm no student heatmap; logout.
13. Enable the OS “remove animations” setting and repeat one tab switch, one detail push and one sheet open.
14. Increase system font size and repeat login, case detail, chat composer and review sheet.

- [ ] **Step 7: 截取关键页面用于视觉复核**

While the app is running on the selected device:

```powershell
cd E:\zhiyu\mobile
New-Item -ItemType Directory -Force build\qa | Out-Null
$devices = flutter devices --machine | ConvertFrom-Json
$deviceId = ($devices | Where-Object { $_.targetPlatform -match 'android|ios' } | Select-Object -First 1).id
if (-not $deviceId) { throw '未发现 Android 或 iOS 设备，无法截图' }
flutter screenshot -d $deviceId -o build\qa\01-login.png
```

Navigate before each command and capture:

```text
01-login.png
02-student-home.png
03-student-cases.png
04-student-chat.png
05-student-profile-heatmap.png
06-teacher-overview.png
07-teacher-review-sheet.png
```

Inspect each image for:

- Logo unchanged and not cropped.
- No text overlap, clipping or horizontal page overflow.
- No oversized headline, dark hero card or decorative gradient.
- At most one emphasized action per first screen.
- Cards use restrained 8px corners; controls feel rounded at 12px.
- Heatmap cells remain tiny and visually close to the user-provided LeetCode reference.
- Student and teacher screens clearly differ by task, not by theme.

QA screenshots under `mobile/build/qa/` are generated evidence and must not be committed.

- [ ] **Step 8: 复核 Git 范围并提交最终清理**

```powershell
cd E:\zhiyu
git status --short
git diff --name-only -- mobile
git diff --check -- mobile
```

Commit only files intentionally changed in this task:

```powershell
$cleanupPaths = @(git diff --name-only -- mobile/lib mobile/test)
if ($cleanupPaths.Count -eq 0) { Write-Output '没有最终清理改动，无需提交'; return }
git commit --only -- $cleanupPaths -m "chore: finish mobile redesign verification"
```

## 2. 规格覆盖矩阵

| 设计要求 | 实施任务 | 自动验证 | 手工验证 |
| --- | --- | --- | --- |
| 同一 App 双身份 | 5, 6 | `role_routing_test.dart` | 两个演示账号登录 |
| 不修改管理端 | 全部 | Git path audit | `git diff --name-only` |
| 保留 Logo | 6, 11, 16 | login/profile image assertions | 截图检查比例与裁切 |
| 全中文 | 6–18 | 文案与 mojibake `rg` 扫描 | 页面逐项阅读 |
| 临床极简、减少卡片 | 2, 3, 7–16 | widget structure tests | 关键页面截图 |
| 苹果式舒适圆角 | 2, 3 | theme token test | 触控与截图检查 |
| 克制过渡、滑动切入 | 2, 5, 9, 15 | reduced-motion and interaction tests | 页面推入、下滑关闭 |
| 学生全页面 | 7–11 | student/chat test suites | 学生完整流程 |
| 教师全页面 | 12–16 | teacher test suite | 教师完整流程 |
| 三个月小方块热力图 | 4, 11 | exactly 91 cell tests | 学生“我的”截图与点击 |
| 加载/空/错/成功状态 | 3, 6–17 | state tests | 断网/空输入/成功反馈 |
| 手机优先、平板可用 | 6–17 | 360/390/430 and text scale tests | 手机与平板走查 |
| WCAG AA 与触控目标 | 2, 3, 17 | semantics/size tests | TalkBack/VoiceOver spot check |
| 不过度设计 | 18 | gradient/shadow/radius scan | 截图审计 |

## 3. 推荐执行批次

The tasks are intentionally ordered. Do not start page styling before Tasks 1–5 are green.

### Batch A: Foundations

Tasks 1–5. Exit criteria: stable tests, theme tokens, shared components, heatmap logic and role shells all pass.

### Batch B: Entry and Student Flow

Tasks 6–11. Exit criteria: student can log in, complete case discovery/chat/feedback/review, and inspect the three-month heatmap.

### Batch C: Teacher Flow

Tasks 12–16. Exit criteria: teacher can review priorities, configure/reference cases, create assignments, process review items and manage profile.

### Batch D: Hardening

Tasks 17–18. Exit criteria: all tests/analyze/build pass; screenshots have been inspected; no overdesign scan violations remain.

## 4. 完成定义

The redesign is complete only when all of the following are true:

- [ ] `flutter analyze` exits 0.
- [ ] `flutter test` exits 0.
- [ ] `flutter build apk --debug` exits 0.
- [ ] Student and teacher role routing tests pass.
- [ ] All 14 existing user-facing pages pass 360×800 at 1.3 text scale without overflow.
- [ ] Student profile renders exactly 91 compact activity cells and the home page renders none.
- [ ] Every visible button performs an action, opens a real surface, or is visibly disabled with a reason.
- [ ] No visible English product labels or mojibake remain.
- [ ] No ordinary page uses decorative gradients, heavy shadows, nested cards or oversized 30px+ headings.
- [ ] Logo remains the existing asset with unchanged content and aspect ratio.
- [ ] Reduced-motion behavior has been tested.
- [ ] Login, student home, cases, chat, student profile, teacher overview and review sheet screenshots have been inspected.
- [ ] Git diff contains only intended `mobile/` source/test changes and excludes build outputs, screenshots and unrelated user work.

## 5. 计划自检结果

### 5.1 规格覆盖

- Scope: all implementation paths are under `mobile/`; Vue and admin paths appear only in the “do not modify” guard.
- Identity: Tasks 5–6 cover one login and role-based workspaces.
- Visual system: Tasks 2–3 define the exact palette, type scale, 8/12/20px radius hierarchy, borders, shadows and controls.
- Student pages: Tasks 7–11 cover every existing student route.
- Teacher pages: Tasks 12–16 cover every existing teacher route.
- Heatmap: Tasks 4 and 11 define 91 compact cells, real dates, four teal intensity levels, summary metrics and day details in student profile only.
- Motion: Tasks 2, 5, 9 and 15 cover tab fades, detail pushes, message insertion, sheets, drag dismissal and reduced motion.
- States and accessibility: Tasks 3, 6–17 cover loading, empty, error, success, semantics, 44px primary controls, text scaling and keyboard behavior.
- Verification: Task 18 covers analyze, tests, debug APK build, live interaction, screenshots and anti-overdesign scans.

No design-spec section is left without an implementation task or an acceptance check.

### 5.2 占位符检查

The plan contains no unresolved markers, invented case IDs or hand-filled shell arguments. Runtime-selected device and cleanup paths are resolved by executable PowerShell. The fixed test case ID `chest-pain` exists in `MockData.cases`.

### 5.3 类型与接口一致性

- `AppMotion.standard(context)` and `AppMotion.routeDuration` match the API defined in Task 2.
- `ZySegment<T>` and `ZySegmentedControl<T>` names are used consistently after Task 3.
- `HeatmapDay.completedCount`, `HeatmapDay.activities`, `TrainingActivitySummary`, `buildTrainingWindow` and `ZyActivityHeatmap` match Task 4 and the profile tests.
- Heatmap keys use unique `ValueKey<String>('activity-cell-YYYY-MM-DD')`; the plan does not reuse one key for 91 sibling cells.
- Student and teacher test files import every page and model referenced by later appended tests.
- `ReviewDetailSheet` constructor fields match its Task 15 call contract.
- The data layer stays independent of profile feature types; activity summary computation remains in the student profile feature.

### 5.4 基线风险

The current repository has a clean analyzer result but one failing legacy widget test and a dirty Git worktree. Task 1 isolates and fixes the test baseline; every commit command uses exact `--only` paths. Execution must stop at the first unexpected diff-scope change rather than resetting or cleaning the worktree.
