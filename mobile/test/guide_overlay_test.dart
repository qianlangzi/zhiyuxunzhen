import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zhiyu_xunzhen/features/common/guide/guide_anchor.dart';
import 'package:zhiyu_xunzhen/features/common/guide/guide_controller.dart';
import 'package:zhiyu_xunzhen/features/common/guide/guide_overlay.dart';

/// 带引导锚点的测试宿主页
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: GuideTarget(
          anchor: GuideAnchors.studentHomeCards,
          child: const SizedBox(width: 320, height: 200, child: Text('卡片区')),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('新手指引：首启播手势速览 → 结束自动接 Tab 引导 → 可点下一步',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 与 app.dart 完全一致的挂载方式：验证 Stack + GuideOverlay 不会让路由页塌缩
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
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

    // 宿主页必须铺满（验证 Stack 松约束没有把导航器压成 0×0）
    final body = tester.getSize(find.byType(Scaffold).first);
    expect(body.width, greaterThan(0));
    expect(body.height, greaterThan(0));

    // 首启：进入学生端「学习」Tab，应先播隐藏手势速览
    container
        .read(guideControllerProvider.notifier)
        .enterTab(GuideRole.student, 'home');
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('向左一滑，唤出问诊助手'), findsOneWidget);
    expect(find.text('隐藏操作'), findsOneWidget);

    // 走完速览 3 步（最后一步按钮是「知道了」）
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('下一步'));
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.tap(find.text('知道了'));
    await tester.pump(const Duration(milliseconds: 700));

    // 速览结束后应自动接上「学习」Tab 引导（带锚点高亮）
    expect(find.text('四张卡片，直达核心'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('底部四个 Tab'), findsOneWidget);

    // 最后一步点「知道了」关闭
    await tester.tap(find.text('知道了'));
    await tester.pump(const Duration(milliseconds: 700));

    // 引导结束后不应残留遮罩
    expect(find.text('底部四个 Tab'), findsNothing);
  });

  testWidgets('新手指引：跳过立即关闭，不再续播 Tab 引导', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
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

    container
        .read(guideControllerProvider.notifier)
        .enterTab(GuideRole.teacher, 'bprep');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('长按卡片，唤出管理菜单'), findsOneWidget);

    await tester.tap(find.text('跳过'));
    await tester.pump(const Duration(milliseconds: 900));

    // 跳过 = 连后续 Tab 引导一起取消
    expect(find.text('新建一次备课'), findsNothing);
  });
}
