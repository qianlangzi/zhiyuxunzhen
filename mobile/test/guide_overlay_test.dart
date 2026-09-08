import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zhiyu_xunzhen/features/common/guide/guide_anchor.dart';
import 'package:zhiyu_xunzhen/features/common/guide/guide_controller.dart';
import 'package:zhiyu_xunzhen/features/common/guide/guide_overlay.dart';
import 'package:zhiyu_xunzhen/features/common/guide/guide_tours.dart';

/// 带引导锚点的测试宿主页（模拟「训练 Tab · 每日一例卡」）
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: GuideTarget(
          anchor: GuideAnchors.studentTrainingDaily,
          child: const SizedBox(width: 320, height: 120, child: Text('每日一例')),
        ),
      ),
    );
  }
}

/// 必须 mock SharedPreferences：
/// widget 测试没有平台通道实现，GuideController 构造时的 _load() 会在
/// getInstance() 上永远挂起（async enterTab 因此卡死 → 测试 10 分钟超时）。
void _mockPrefs() => SharedPreferences.setMockInitialValues({});

Future<void> _pumpHost(WidgetTester tester, ProviderContainer container) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        // 与 app.dart 完全一致的挂载方式：验证 Stack + GuideOverlay
        // 不会让路由页塌缩，也验证毛玻璃卡片能正常渲染
        builder: (context, child) => Stack(
          children: [
            SizedBox.expand(child: child),
            const GuideOverlay(),
          ],
        ),
        home: const _Home(),
      ),
    ),
  );
}

/// 走完当前引导的所有步骤
Future<void> _walkThrough(WidgetTester tester) async {
  for (var guard = 0; guard < 12; guard++) {
    if (find.text('知道了').evaluate().isNotEmpty) {
      await tester.tap(find.text('知道了'));
      await tester.pump(const Duration(milliseconds: 700));
      return;
    }
    if (find.text('下一步').evaluate().isEmpty) return;
    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(milliseconds: 700));
  }
}

void main() {
  setUp(_mockPrefs);

  test('不需要引导的 Tab 不配内容（避免无意义打扰）', () {
    // 学习 / 我的这些全人类常识页，必须返回 null
    expect(GuideTours.of(GuideRole.student, 'home'), isNull);
    expect(GuideTours.of(GuideRole.student, 'profile'), isNull);
    expect(GuideTours.of(GuideRole.teacher, 'home'), isNull);
    expect(GuideTours.of(GuideRole.teacher, 'profile'), isNull);
    // 只有真正藏了交互的 Tab / 页面才保留
    expect(GuideTours.of(GuideRole.student, 'training'), isNotNull);
    expect(GuideTours.of(GuideRole.student, 'growth'), isNotNull);
    expect(GuideTours.of(GuideRole.teacher, 'bprep'), isNotNull);
    expect(GuideTours.of(GuideRole.teacher, 'classes'), isNotNull);
    expect(GuideTours.pageOf(GuidePageIds.studentChat), isNotNull);
    expect(GuideTours.pageOf('不存在的页面'), isNull);
  });

  testWidgets('首启播手势速览，看完后进入 Tab 引导', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpHost(tester, container);

    // 宿主页必须铺满（验证 Stack 松约束没把导航器压成 0×0）
    expect(tester.getSize(find.byType(Scaffold).first).width, greaterThan(0));

    final notifier = container.read(guideControllerProvider.notifier);
    notifier.bindTabResolver(() => 'training');
    await notifier.enterTab(GuideRole.student, 'training');
    await tester.pump(const Duration(milliseconds: 700));

    // 先播隐藏手势速览
    expect(find.text('向左一滑，唤出问诊助手'), findsOneWidget);
    await _walkThrough(tester);
    await tester.pump(const Duration(milliseconds: 800));

    // 速览走完 → 自动接上「训练」Tab 引导（带锚点高亮）
    expect(find.text('每日一例：写完有 AI 逐段批改'), findsOneWidget);
  });

  testWidgets('看过的引导不再重播（核心回归：不能每次都弹）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpHost(tester, container);

    final notifier = container.read(guideControllerProvider.notifier);
    notifier.bindTabResolver(() => 'training');

    // —— 第一次：完整看完速览 + Tab 引导 ——
    await notifier.enterTab(GuideRole.student, 'training');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('向左一滑，唤出问诊助手'), findsOneWidget);
    await _walkThrough(tester);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('每日一例：写完有 AI 逐段批改'), findsOneWidget);
    await _walkThrough(tester);
    await tester.pump(const Duration(milliseconds: 700));

    // 播完必须留痕
    expect(notifier.isDone('student_intro'), isTrue);
    expect(notifier.isDone('student_training'), isTrue);
    expect(find.text('向左一滑，唤出问诊助手'), findsNothing);

    // —— 再次进入：一律静默 ——
    for (var i = 0; i < 3; i++) {
      await notifier.enterTab(GuideRole.student, 'training');
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('向左一滑，唤出问诊助手'), findsNothing);
      expect(find.text('每日一例：写完有 AI 逐段批改'), findsNothing);
    }
  });

  testWidgets('跳过立即关闭，且后续不再续播', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpHost(tester, container);

    final notifier = container.read(guideControllerProvider.notifier);
    notifier.bindTabResolver(() => 'bprep');
    await notifier.enterTab(GuideRole.teacher, 'bprep');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('长按卡片，菜单才出来'), findsOneWidget);

    await tester.tap(find.text('跳过'));
    await tester.pump(const Duration(milliseconds: 1000));

    // 跳过 = 连 Tab 引导一起取消
    expect(find.text('长按教案卡，管它'), findsNothing);
    expect(notifier.isDone('teacher_intro'), isTrue);

    // 再次进入也不再打扰
    await notifier.enterTab(GuideRole.teacher, 'bprep');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('长按教案卡，管它'), findsNothing);
  });

  testWidgets('页面级引导：二级页首次进入播一次，第二次静默', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpHost(tester, container);

    final notifier = container.read(guideControllerProvider.notifier);

    // 页面引导不依赖 Tab resolver，也不该衔接 Tab 引导
    notifier.schedulePageEnter(GuidePageIds.studentMr, delay: Duration.zero);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('「问 AI」连续点，提示会升级'), findsOneWidget);

    await _walkThrough(tester);
    await tester.pump(const Duration(milliseconds: 900));
    expect(notifier.isDone(GuidePageIds.studentMr), isTrue);
    expect(find.text('「问 AI」连续点，提示会升级'), findsNothing);

    // 二次进入同一页面：静默
    notifier.schedulePageEnter(GuidePageIds.studentMr, delay: Duration.zero);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('「问 AI」连续点，提示会升级'), findsNothing);
  });

  testWidgets('页面引导与 Tab 引导互斥：正播时不被打断', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpHost(tester, container);

    final notifier = container.read(guideControllerProvider.notifier);

    await notifier.enterTab(GuideRole.student, 'training');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('向左一滑，唤出问诊助手'), findsOneWidget);

    // 速览播放中，页面触发应被忽略，而不是抢断
    notifier.schedulePageEnter(GuidePageIds.studentChat, delay: Duration.zero);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('卡住了？向左滑一下'), findsNothing);
    expect(find.text('向左一滑，唤出问诊助手'), findsOneWidget);
  });
}
